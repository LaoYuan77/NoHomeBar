//
//  NoHomeBar.swift
//  NoHomeBar
//
//  Created by straight-tamago★ on 2022/12/28.
//  Optimized for iOS 14.3+ page-lock persistence & retry verification.
//

import UIKit
import SwiftUI
import Darwin

// 持久保存已锁定的 16KB 内存页映射，防止函数返回或 GC 后被内核释放
private var lockedMappings: [String: (ptr: UnsafeMutableRawPointer, size: Int, fd: Int32)] = [:]
private let lockQueue = DispatchQueue(label: "com.nohomebar.lockqueue")

/// 在注销（Respring）期间高频访问并锁定目标页，保持硬件 PTE 引用位活跃，防止被 Jetsam 回收
func touchAndKeepPageAlive(TargetFilePath: String, ExpectedHeader: String) {
    let expectedBytes = Array(ExpectedHeader.utf8)
    lockQueue.sync {
        if let entry = lockedMappings[TargetFilePath] {
            // 强制读取整页内容以刷新内核 LRU 页表活跃状态
            let bytePtr = entry.ptr.assumingMemoryBound(to: UInt8.self)
            var checksum: UInt8 = 0
            for idx in stride(from: 0, to: entry.size, by: 64) {
                checksum ^= bytePtr[idx]
            }
            _ = checksum
            mlock(entry.ptr, entry.size)
        }
    }
    // 如果检测到内存页被系统还原，立即重新写入
    let fd = open(TargetFilePath, O_RDONLY | O_CLOEXEC)
    if fd >= 0 {
        var header = [UInt8](repeating: 0, count: expectedBytes.count)
        let readCount = read(fd, &header, expectedBytes.count)
        close(fd)
        if readCount == expectedBytes.count && header != expectedBytes {
            _ = overwrite(TargetFilePath: TargetFilePath, OverwriteData: ExpectedHeader)
        }
    }
}

func overwrite(TargetFilePath: String, OverwriteData: String) -> String {
    let base = "0123456789"
    let randomStr = String((0..<2).map { _ in base.randomElement()! })
    let OverwriteFileData = OverwriteData.data(using: .utf8)!
    let pageSize = 0x4000 // iOS ARM64 16KB 页大小

    let fd = open(TargetFilePath, O_RDONLY | O_CLOEXEC)
    guard fd >= 0 else {
        print("open Error")
        return "open Error - " + randomStr
    }

    var st = stat()
    var mapSize = pageSize
    if fstat(fd, &st) == 0 && st.st_size > 0 {
        mapSize = min(Int(st.st_size), pageSize)
    }

    guard let Map = mmap(nil, mapSize, PROT_READ, MAP_SHARED, fd, 0), Map != MAP_FAILED else {
        close(fd)
        print("mmap Error")
        return "mmap Error - " + randomStr
    }

    // 锁定整块 16KB 内存页（而非仅锁定 3 个字节），并持久化保存映射防止释放
    _ = mlock(Map, mapSize)
    lockQueue.sync {
        if let old = lockedMappings[TargetFilePath] {
            munmap(old.ptr, old.size)
            close(old.fd)
        }
        lockedMappings[TargetFilePath] = (ptr: Map, size: mapSize, fd: fd)
    }

    for chunkOff in stride(from: 0, to: OverwriteFileData.count, by: pageSize) {
        let endIdx = min(OverwriteFileData.count, chunkOff + pageSize - 1)
        let dataChunk = OverwriteFileData[chunkOff..<endIdx]
        var overwroteOne = false

        // 提升重试次数至 6 次，每次写入后通过 memcmp 校验内存页是否真实改变
        for attempt in 0..<6 {
            let overwriteSucceeded = dataChunk.withUnsafeBytes { dataChunkBytes -> Bool in
                guard let baseAddr = dataChunkBytes.baseAddress else { return false }
                let ok = unaligned_copy_switch_race(
                    fd, Int64(chunkOff), baseAddr, dataChunkBytes.count)
                if !ok { return false }
                // 回读校验：确认目标内存映射的前 N 个字节确实已变成目标内容
                return memcmp(Map.advanced(by: chunkOff), baseAddr, dataChunkBytes.count) == 0
            }
            if overwriteSucceeded {
                _ = mlock(Map, mapSize)
                overwroteOne = true
                break
            }
            print("Retry page overwrite attempt \(attempt + 1)")
            usleep(50_000) // 间隔 50ms 快速重试，避免 sleep(1) 阻塞主线程
        }

        guard overwroteOne else {
            print("unknown Error")
            return "unknown Error - " + randomStr
        }
    }

    print("Success")
    return "Success - " + randomStr
}

func IsSucceeded(TargetFilePath: String) -> Bool {
    let cleanPath = TargetFilePath.replacingOccurrences(of: "file://", with: "")
    let fd = open(cleanPath, O_RDONLY | O_CLOEXEC)
    guard fd >= 0 else {
        return false
    }
    defer { close(fd) }

    var buf = [UInt8](repeating: 0, count: 3)
    let bytesRead = read(fd, &buf, 3)
    guard bytesRead == 3 else {
        return false
    }
    // 检查前 3 个字节是否为 "xxx" (0x78, 0x78, 0x78)
    return buf[0] == 0x78 && buf[1] == 0x78 && buf[2] == 0x78
}
