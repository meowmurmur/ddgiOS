//
//  NewTabPageMessagesModel.swift
//  DuckDuckGo
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Core
import Foundation
import RemoteMessaging

final class NewTabPageMessagesModel: ObservableObject {

    @Published private(set) var homeMessageViewModels: [HomeMessageViewModel] = []

    private var observable: NSObjectProtocol?

    private let homePageMessagesConfiguration: HomePageMessagesConfiguration
    private let notificationCenter: NotificationCenter
    private let pixelFiring: PixelFiring.Type

    init(homePageMessagesConfiguration: HomePageMessagesConfiguration = AppDependencyProvider.shared.homePageConfiguration,
         notificationCenter: NotificationCenter = .default,
         pixelFiring: PixelFiring.Type = Pixel.self) {
        self.homePageMessagesConfiguration = homePageMessagesConfiguration
        self.notificationCenter = notificationCenter
        self.pixelFiring = pixelFiring
    }

    func load() {
        observable = notificationCenter.addObserver(
            forName: RemoteMessagingStore.Notifications.remoteMessagesDidChange,
            object: nil,
            queue: .main) { [weak self] _ in
                self?.refresh()
        }

        refresh()
    }

    func dismissHomeMessage(_ homeMessage: HomeMessage) {
        homePageMessagesConfiguration.dismissHomeMessage(homeMessage)
        updateHomeMessageViewModel()
    }

    func didAppear(_ homeMessage: HomeMessage) {
        homePageMessagesConfiguration.didAppear(homeMessage)
    }

    // MARK: - Private

    private func refresh() {
        homePageMessagesConfiguration.refresh()
        updateHomeMessageViewModel()
    }

    private func updateHomeMessageViewModel() {
        self.homeMessageViewModels = homePageMessagesConfiguration.homeMessages.compactMap(self.homeMessageViewModel(for:))
    }

    private func homeMessageViewModel(for message: HomeMessage) -> HomeMessageViewModel? {
        switch message {
        case .placeholder:
            return HomeMessageViewModel(messageId: "", modelType: .small(titleText: "", descriptionText: "")) { [weak self] _ in
                self?.dismissHomeMessage(message)
            } onDidAppear: {
                // no-op
            }
        case .remoteMessage(let remoteMessage):
            return HomeMessageViewModelBuilder.build(for: remoteMessage) { [weak self] action in

                guard let action,
                        let self else { return }

                switch action {

                case .action(let isSharing):
                    if !isSharing {
                        self.dismissHomeMessage(message)
                    }
                    pixelFiring.fire(.remoteMessageActionClicked,
                                     withAdditionalParameters: [PixelParameters.message: "\(remoteMessage.id)"])

                case .primaryAction(let isSharing):
                    if !isSharing {
                        self.dismissHomeMessage(message)
                    }
                    pixelFiring.fire(.remoteMessagePrimaryActionClicked,
                                     withAdditionalParameters: [PixelParameters.message: "\(remoteMessage.id)"])

                case .secondaryAction(let isSharing):
                    if !isSharing {
                        self.dismissHomeMessage(message)
                    }
                    pixelFiring.fire(.remoteMessageSecondaryActionClicked,
                                     withAdditionalParameters: [PixelParameters.message: "\(remoteMessage.id)"])

                case .close:
                    self.dismissHomeMessage(message)
                    pixelFiring.fire(.remoteMessageDismissed,
                                     withAdditionalParameters: [PixelParameters.message: "\(remoteMessage.id)"])

                }
            } onDidAppear: { [weak self] in
                self?.homePageMessagesConfiguration.didAppear(message)
            }
        }
    }
}
