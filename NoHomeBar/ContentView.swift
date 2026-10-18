//
//  ContentView.swift
//  NoHomeBar
//
//  Created by straight-tamago★ on 2022/12/28.
//  Optimized for iPhone 12 Pro Max (iOS 14.3) stability & respring persistence.
//

import SwiftUI
import AudioToolbox
import Darwin

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    @State private var isVibrationOn = false
    @State private var LogMessage = ""
    @State private var ViewLog = true
    @State private var Respring_confirm = false
    @State private var SettingsShowing = false
    @State private var Restore_Confirm = false
    @State private var Update_Alert = false
    @State private var Update_Available = false
    @State private var Notcompatiblewithios14 = false
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    @State private var targetHeader: String = "xxx"

    struct TargetFilesPath_Struct: Identifiable {
        var id = UUID()
        let title: String
        let path: String
    }

    @State private var TargetFilesPath = [
        TargetFilesPath_Struct(
            title: "Assets.car",
            path: "/System/Library/PrivateFrameworks/MaterialKit.framework/Assets.car"
        ),
    ]

    var body: some View {
        VStack {
            if ViewLog {
                Text("")
                    .frame(width: 300, height: 200)
                    .disabled(true)
            }
            Text("NoHomeBar__").font(.largeTitle).fontWeight(.bold)
                .alert(isPresented: $Respring_confirm) {
                    Alert(
                        title: Text("Restart SpringBoard"),
                        message: Text("Memory page is locked. Tap Restart to apply, or choose Later to respring manually via TrollStore."),
                        primaryButton: .destructive(Text("Restart"), action: Respring),
                        secondaryButton: .default(Text("Later (Keep Locked)"))
                    )
                }
            HStack {
                //---------------------------------------------------------------------------
                if TargetFilesPath.allSatisfy({ IsSucceeded(TargetFilePath: "file://" + $0.path) == true }) == false {
                    Button("Disable HomeBar") {
                        Disable_ShutterSound()
                    }
                    .padding()
                    .accentColor(Color.white)
                    .background(Color.blue)
                    .cornerRadius(26)
                    .shadow(color: Color.purple, radius: 15, x: 0, y: 5)
                } else {
                    Button("Restore HomeBar") {
                        Restore_Confirm = true
                    }
                    .padding()
                    .accentColor(Color.white)
                    .background(Color.blue)
                    .cornerRadius(26)
                    .shadow(color: Color.purple, radius: 15, x: 0, y: 5)
                    .alert(isPresented: $Restore_Confirm) {
                        Alert(
                            title: Text("Restore HomeBar?"),
                            primaryButton: .destructive(Text("Restore"), action: Restore_ShutterSound),
                            secondaryButton: .default(Text("Cancel"))
                        )
                    }
                }
                //---------------------------------------------------------------------------
                Button {
                    SettingsShowing = true
                } label: {
                    Image(systemName: "info.circle")
                        .padding()
                        .accentColor(Color.white)
                        .background(Color.blue)
                        .cornerRadius(26)
                        .shadow(color: Color.purple, radius: 15, x: 0, y: 5)
                }.actionSheet(isPresented: $SettingsShowing) {
                    ActionSheet(title: Text("NoHomeBar v\(version)"), message: Text("by straight-tamago (iOS 14+ Optimized)"), buttons: [
                        .default(Text("Source Code")) {
                            if let url = URL(string: "https://github.com/straight-tamago/NoHomeBar") {
                                UIApplication.shared.open(url)
                            }
                        },
                        .default(Text("MacDirtyCowDemo (Exploit)")) {
                            if let url = URL(string: "https://github.com/zhuowei/MacDirtyCowDemo") {
                                UIApplication.shared.open(url)
                            }
                        },
                        // 解除原版对 iOS 14 的人为屏蔽，允许 iOS 14.3 开启打开 App 自动执行
                        .default(Text("\(NSLocalizedString("Auto run when the app starts (Status: ", comment: ""))\(UserDefaults.standard.bool(forKey: "AutoRun")))")) {
                            let current = UserDefaults.standard.bool(forKey: "AutoRun")
                            UserDefaults.standard.set(!current, forKey: "AutoRun")
                        },
                        .default(Text("\(NSLocalizedString("View Log (Status: ", comment: ""))\(UserDefaults.standard.bool(forKey: "ViewLog")))")) {
                            if UserDefaults.standard.bool(forKey: "ViewLog") == true {
                                UserDefaults.standard.set(false, forKey: "ViewLog")
                                ViewLog = false
                            } else {
                                UserDefaults.standard.set(true, forKey: "ViewLog")
                                ViewLog = true
                            }
                        },
                        .default(Text("\(NSLocalizedString("Update Check", comment: ""))")) {
                            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
                            let url = URL(string: "https://api.github.com/repos/straight-tamago/NoHomeBar/releases/latest")
                            let task = URLSession.shared.dataTask(with: url!) { (data, response, error) in
                                guard let data = data else { return }
                                do {
                                    let object = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as! [String: Any]
                                    let latast_v = object["tag_name"]!
                                    if version != latast_v as! String {
                                        print("update")
                                        Update_Available = true
                                        Update_Alert = true
                                    } else {
                                        print("no update")
                                        Update_Available = false
                                        Update_Alert = true
                                    }
                                } catch {
                                    print(error)
                                }
                            }
                            task.resume()
                        },
                        .cancel()
                    ])
                }
                .alert(isPresented: $Notcompatiblewithios14) {
                    Alert(
                        title: Text("Not compatible with ios14"),
                        primaryButton: .destructive(Text("OK")),
                        secondaryButton: .default(Text("Cancel"))
                    )
                }
                .alert(isPresented: $Update_Alert) {
                    if Update_Available == true {
                        return Alert(
                            title: Text("Update available"),
                            message: Text("Do you want to download the update from the Github ?"),
                            primaryButton: .destructive(Text("OK"), action: {
                                if let url = URL(string: "https://github.com/straight-tamago/NoHomeBar/releases") {
                                    UIApplication.shared.open(url)
                                }
                            }),
                            secondaryButton: .default(Text("Cancel"))
                        )
                    } else {
                        return Alert(
                            title: Text("No Update"),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }
                //---------------------------------------------------------------------------
            }
            if ViewLog {
                Text(LogMessage)
                    .padding(.top, 10)
                List {
                    ForEach(TargetFilesPath) { item in
                        HStack {
                            Text(item.title)
                            Spacer()
                            if IsSucceeded(TargetFilePath: "file://" + item.path) == true {
                                Text("OFF").foregroundColor(.green)
                            } else {
                                Text("ON").foregroundColor(.red)
                            }
                        }
                    }.frame(height: 1)
                }
                .listStyle(.plain)
                .frame(width: 300, height: 200)
            } else {
                Text(LogMessage)
                    .padding(.top, 10)
            }
        }
        .onAppear {
            LogMessage = "v\(version)"
            if UserDefaults.standard.bool(forKey: "ViewLog") == false {
                ViewLog = false
            }
            // 将列表状态刷新间隔调整为 1.5 秒，并配合轻量级 read 避免频繁读取整文件
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                TargetFilesPath[0].id = UUID()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                print("进入后台：启动内存页守护任务")
                startBackgroundPageGuard()
            }
            if phase == .active {
                print("回到前台")
                if UserDefaults.standard.bool(forKey: "AutoRun") == true {
                    Disable_ShutterSound()
                }
            }
        }
    }

    // ---------------------------------------------------------------------------------------
    /// 后台守护：在切换到桌面或使用 TrollStore 注销期间，持续在后台锁住并巡检 Assets.car 内存页
    func startBackgroundPageGuard() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "NoHomeBarPageGuard") {
            if self.backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                self.backgroundTaskID = .invalid
            }
        }
        let paths = TargetFilesPath.map { $0.path }
        let expected = targetHeader
        DispatchQueue.global(qos: .userInteractive).async {
            // 在后台持续守护 15 秒（覆盖切换去 TrollStore 点击 Respring 的全过程）
            for _ in 0..<75 {
                for p in paths {
                    touchAndKeepPageAlive(TargetFilePath: p, ExpectedHeader: expected)
                }
                usleep(200_000) // 每 200ms 巡检一次
            }
        }
    }

    func Disable_ShutterSound() {
        LogMessage = "Disabling..."
        targetHeader = "xxx"
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        startBackgroundPageGuard()

        let paths = TargetFilesPath.map { $0.path }
        DispatchQueue.global(qos: .userInteractive).async {
            var lastResult = ""
            // 修复原版 i/10 整数除法等于 0 的 Bug，改为真正间隔 120ms 的多轮写入与校验
            for pass in 0..<4 {
                for path in paths {
                    lastResult = overwrite(TargetFilePath: path, OverwriteData: "xxx")
                    touchAndKeepPageAlive(TargetFilePath: path, ExpectedHeader: "xxx")
                }
                if pass < 3 {
                    usleep(120_000)
                }
            }
            DispatchQueue.main.async {
                self.LogMessage = lastResult
                self.TargetFilesPath[0].id = UUID()
                // 确认写入并锁定完成后，延迟 0.2 秒再弹出注销确认框
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.Respring_confirm = true
                }
            }
        }
    }

    func Restore_ShutterSound() {
        LogMessage = "Restoring..."
        targetHeader = "BOM"
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        startBackgroundPageGuard()

        let paths = TargetFilesPath.map { $0.path }
        DispatchQueue.global(qos: .userInteractive).async {
            var lastResult = ""
            for pass in 0..<4 {
                for path in paths {
                    lastResult = overwrite(TargetFilePath: path, OverwriteData: "BOM")
                    touchAndKeepPageAlive(TargetFilePath: path, ExpectedHeader: "BOM")
                }
                if pass < 3 {
                    usleep(120_000)
                }
            }
            DispatchQueue.main.async {
                self.LogMessage = lastResult
                self.TargetFilesPath[0].id = UUID()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.Respring_confirm = true
                }
            }
        }
    }

    func Respring() {
        let paths = TargetFilesPath.map { $0.path }
        let expected = targetHeader

        // 启动最高优先级后台线程：在注销全过程中每 10ms 刷新一次内存页活跃位并在被回收时立即重写
        // 彻底解决 snapshotView 撑爆内存时内核 LRU 淘汰 Assets.car 缓存页的问题
        DispatchQueue.global(qos: .userInteractive).async {
            while true {
                for p in paths {
                    touchAndKeepPageAlive(TargetFilePath: p, ExpectedHeader: expected)
                }
                usleep(10_000) // 10ms
            }
        }

        // 优先尝试调用系统 killall 温和重启 SpringBoard（在具有 TrollStore 无沙盒权限或越狱环境下直接生效，不消耗内存）
        var pid: pid_t = 0
        let killallPaths = ["/usr/bin/killall", "/var/jb/usr/bin/killall"]
        for binPath in killallPaths {
            if access(binPath, X_OK) == 0 {
                let arg0 = strdup(binPath)
                let arg1 = strdup("-9")
                let arg2 = strdup("SpringBoard")
                let arg3 = strdup("backboardd")
                var argv: [UnsafeMutablePointer<CChar>?] = [arg0, arg1, arg2, arg3, nil]
                posix_spawn(&pid, binPath, nil, nil, &argv, nil)
                free(arg0); free(arg1); free(arg2); free(arg3)
            }
        }

        // 等待 150ms 让后台守护线程完成首轮内存页锁定后，再执行兜底的 snapshotView 刷新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let sharedApplication = UIApplication.shared
            let windows = sharedApplication.windows
            if let window = windows.first {
                while true {
                    window.snapshotView(afterScreenUpdates: false)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
