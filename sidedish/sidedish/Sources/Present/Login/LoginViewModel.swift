//
//  LoginViewModel.swift
//  sidedish
//
//  Created by seongha shin on 2022/04/25.
//

import Combine
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn

struct LoginViewModelAction {
    let viewDidLoad = PassthroughSubject<Void, Never>()
    let tappedGoogleLogin = PassthroughSubject<Void, Never>()
    let googleUser = PassthroughSubject<GIDGoogleUser?, Never>()
}

struct LoginViewModelState {
    let presentMainView = PassthroughSubject<Void, Never>()
    let presentGoogleLogin = PassthroughSubject<GIDConfiguration, Never>()
}

protocol LoginViewModelBinding {
    var action: LoginViewModelAction { get }
    var state: LoginViewModelState { get }
}

typealias LoginViewModelProtocol = LoginViewModelBinding

class LoginViewModel: LoginViewModelProtocol {
    
    private var cancellables = Set<AnyCancellable>()
    private let loginRepository: LoginRepository = LoginRepositoryImpl()
    
    let action = LoginViewModelAction()
    let state = LoginViewModelState()
    
    init() {
        action.viewDidLoad
            .compactMap { self.loginRepository.getUser() }
            .switchToLatest()
            .handleEvents(receiveOutput: { Container.shared.userStore.user = $0 })
            .sink { _ in
                self.state.presentMainView.send()
            }
            .store(in: &cancellables)
        
        action.tappedGoogleLogin
            .compactMap { _ -> GIDConfiguration? in
                guard let clientId = FirebaseApp.app()?.options.clientID else {
                    return nil
                }
                return GIDConfiguration(clientID: clientId)
            }
            .sink(receiveValue: state.presentGoogleLogin.send(_:))
            .store(in: &cancellables)
        
        action.googleUser
            .compactMap { user -> AuthCredential? in
                guard let authentication = user?.authentication,
                      let idToken = authentication.idToken else {
                    return nil
                }
                return GoogleAuthProvider.credential(withIDToken: idToken, accessToken: authentication.accessToken)
            }
            .map { self.loginRepository.googleLogin(authCredential: $0) }
            .switchToLatest()
            .handleEvents(receiveOutput: { Container.shared.userStore.user = $0 })
            .map { _ in }
            .sink(receiveValue: state.presentMainView.send(_:))
            .store(in: &cancellables)
    }
}