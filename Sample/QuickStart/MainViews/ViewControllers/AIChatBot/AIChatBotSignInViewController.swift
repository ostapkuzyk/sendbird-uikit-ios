//
//  AIChatBotSignInViewController.swift
//  QuickStart
//
//  Created by Jed Gyeong on 5/14/24.
//  Copyright © 2024 SendBird, Inc. All rights reserved.
//

import UIKit
import SendbirdChatSDK

class AIChatBotSignInViewController: UIViewController {
    @IBOutlet weak var applicationIdTextField: UITextField!
    @IBOutlet weak var botIdTextField: UITextField!
    @IBOutlet weak var userIdTextField: UITextField!
    @IBOutlet weak var nicknameTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var regionTextField: UITextField!
    @IBOutlet weak var regionSelectionView: UIView!
    @IBOutlet weak var regionContainerView: UIView!
    @IBOutlet weak var regionContainerTopMarginView: UIView!
    
    @IBOutlet weak var versionLabel: UILabel!
    
    let sampleAppType: SampleAppType = .chatBot
    
    #if INSPECTION
    var region: Region = .production
    #endif
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let signedApp = UserDefaults.loadSignedInSampleApp()
        if signedApp != .none {
            self.signIn()
        }
        
        #if INSPECTION
        AppDelegate.bringInspectionViewToFront()
        #endif
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(touchView(_:)))
        self.view.addGestureRecognizer(tap)

        loadingIndicator.isHidden = true
        signInButton.layer.cornerRadius = ViewController.CornerRadius.small.rawValue
        [applicationIdTextField, botIdTextField, userIdTextField, nicknameTextField, regionTextField].forEach {
            guard let textField = $0 else { return }
            let paddingView = UIView(frame: CGRect(
                x: 0,
                y: 0,
                width: 16,
                height: textField.frame.size.height)
            )
            textField.leftView = paddingView
            textField.delegate = self
            textField.leftViewMode = .always
            textField.layer.borderWidth = 1
            textField.layer.cornerRadius = 4
            textField.layer.borderColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
            textField.tintColor = #colorLiteral(red: 0.4666666667, green: 0.337254902, blue: 0.8549019608, alpha: 1)
        }
        
        self.applicationIdTextField.text = UserDefaults.loadAppId(type: self.sampleAppType)
        self.botIdTextField.text = UserDefaults.loadBotId()
        self.userIdTextField.text = UserDefaults.loadUserId(type: self.sampleAppType)
        self.nicknameTextField.text = UserDefaults.loadNickname(type: self.sampleAppType)
        
        #if INSPECTION
        self.setupRegionSelectionView()
        #endif
        
        self.setupVersion()
    }
    
    @objc
    func touchView(_ sender: Any) {
        self.view.endEditing(true)
    }
    
    @IBAction func clickSelectSampleAppsButton(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func clickSignInButton(_ sender: Any) {
        self.signIn()
    }
    
    func signIn() {
        self.view.isUserInteractionEnabled = false
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimating()
        
        let appId = applicationIdTextField.text ?? ""
        let botId = botIdTextField.text ?? ""
        let userId = userIdTextField.text ?? ""
        let nickname = nicknameTextField.text ?? ""

        guard !appId.isEmpty else {
            applicationIdTextField.shake()
            applicationIdTextField.becomeFirstResponder()
            loadingIndicator.stopAnimating()
            view.isUserInteractionEnabled = true
            return
        }
        
        guard !botId.isEmpty else {
            botIdTextField.shake()
            botIdTextField.becomeFirstResponder()
            loadingIndicator.stopAnimating()
            view.isUserInteractionEnabled = true
            return
        }
        
        guard !userId.isEmpty else {
            userIdTextField.shake()
            userIdTextField.becomeFirstResponder()
            loadingIndicator.stopAnimating()
            view.isUserInteractionEnabled = true
            return
        }
        
        guard !nickname.isEmpty else {
            nicknameTextField.shake()
            nicknameTextField.becomeFirstResponder()
            loadingIndicator.stopAnimating()
            view.isUserInteractionEnabled = true
            return
        }
        
        SBUGlobals.currentUser = SBUUser(
            userId: userId,
            nickname: nickname
        )
        
        #if INSPECTION
        let region = UserDefaults.loadRegion(type: self.sampleAppType)
        SBUGlobals.apiHost = region.apiHost(appId: appId)
        SBUGlobals.wsHost = region.wsHost(appId: appId)
        #endif

        SendbirdUI.initialize(
            applicationId: appId,
            initParamsBuilder: { params in
            params?.isLocalCachingEnabled = true
        },
            migrationHandler: {

        },
            completionHandler: { error in
            SendbirdUI.connect { [weak self] user, error in
                guard let self = self else { return }
                
                self.loadingIndicator.stopAnimating()
                self.view.isUserInteractionEnabled = true
                
                if let user = user {
                    self.saveSignInfo(
                        appId: appId,
                        botId: botId,
                        userId: userId,
                        nickname: nickname
                    )
                    
                    UserDefaults.saveSignedSampleApp(type: .chatBot)

                    print("SendbirdUIKit.connect: \(user)")
                    self.openViewController(botId: botId)
                }
            }
        })
    }
    
    func saveSignInfo(appId: String, botId: String, userId: String, nickname: String) {
        UserDefaults.saveAppId(type: self.sampleAppType, appId: appId)
        UserDefaults.saveBotId(botId: botId)
        UserDefaults.saveUserId(type: self.sampleAppType, userId: userId)
        UserDefaults.saveNickname(type: self.sampleAppType, nickname: nickname)
        
    }
    
    func openViewController(botId: String) {
        let chatBotVC = AIChatBotViewController()
        chatBotVC.botId = botId
        self.navigationController?.pushViewController(chatBotVC, animated: true)
    }
    
    func moveToCustomSamples() {
        SBUTheme.set(theme: .light)
        let mainVC = CustomBaseViewController(style: .grouped)
        let naviVC = UINavigationController(rootViewController: mainVC)
        naviVC.modalPresentationStyle = .fullScreen
        present(naviVC, animated: true)
    }
    
    func setupVersion() {
        let coreVersion: String = SendbirdChat.getSDKVersion()
        var uikitVersion: String {
            if SendbirdUI.shortVersion == "3.27.5" {
                let bundle = Bundle(identifier: "com.sendbird.uikit.sample")
                return "\(bundle?.infoDictionary?["CFBundleShortVersionString"] ?? "")"
            } else if SendbirdUI.shortVersion == "0.0.0" {
                guard let dictionary = Bundle.main.infoDictionary,
                      let appVersion = dictionary["CFBundleShortVersionString"] as? String,
                      let build = dictionary["CFBundleVersion"] as? String else {return ""}
                return "\(appVersion)(\(build))"
            } else {
                return SendbirdUI.shortVersion
            }
        }
        versionLabel.text = "UIKit v\(uikitVersion)\tSDK v\(coreVersion)"
    }
}

extension AIChatBotSignInViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

