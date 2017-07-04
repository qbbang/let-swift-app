//
//  EventsViewControllerViewModel.swift
//  LetSwift
//
//  Created by Kinga Wilczek, Marcin Chojnacki on 24.04.2017.
//  Copyright © 2017 Droids On Roids. All rights reserved.
//

import Foundation
import CoreLocation

final class EventsViewControllerViewModel {

    enum AttendanceState {
        case notAttending
        case attending
        case loading
        case notAllowed
    }
    
    enum NotificationState {
        case notVisible
        case notActive
        case active
    }

    private enum Constants {
        static let minimumTimeForReminder: TimeInterval = 24.0 * 60.0 * 60.0
    }
    
    private let disposeBag = DisposeBag()
    private var eventDetailsId: Int?
    
    var lastEventObservable: Observable<Event?>
    var tableViewStateObservable: Observable<AppContentState>
    var attendanceStateObservable = Observable<AttendanceState>(.loading)
    var notificationStateObservable = Observable<NotificationState>(.notActive)
    var facebookAlertObservable = Observable<String?>(nil)
    var loginScreenObservable = Observable<Void>()
    var summaryCellDidTapObservable = Observable<Void>()
    var locationCellDidTapObservable = Observable<Void>()
    
    var eventsListRefreshObservable = Observable<Void>()
    var previousEventsCellDidSetObservable = Observable<Void>()
    var previousEventsViewModelObservable = Observable<PreviousEventsListCellViewModel?>(nil)
    var previousEventsObservable = Observable<[Event?]?>(nil)
    
    var eventDetailsRefreshObservable = Observable<Void>()
    var carouselEventPhotosViewModelObservable = Observable<CarouselEventPhotosCellViewModel?>(nil)
    var lectureCellDidTapObservable = Observable<Talk?>(nil)
    var speakerCellDidTapObservable = Observable<Int>(-1)

    var eventDidFinishObservable = Observable<Event?>(nil)

    var notificationPermissionsNotGrantedObservable = Observable<Void>()

    var notificationManager: NotificationManager!
    weak var delegate: EventsViewControllerDelegate?
    
    var isReminderAllowed: Bool {
        guard let date = lastEventObservable.value?.date else { return false }
        return !date.addingTimeInterval(-Constants.minimumTimeForReminder).isOutdated
    }

    var isEventOutdated: Bool {
        guard let date = lastEventObservable.value?.date else { return false }
        return date.isOutdated
    }
    
    init(events: [Event]?, delegate: EventsViewControllerDelegate?) {
        lastEventObservable = Observable<Event?>(events?.first)
        tableViewStateObservable = Observable<AppContentState>(events?.isEmpty ?? true ? .error : .content)
        previousEventsObservable = Observable<[Event?]?>(events?.tail)
        self.delegate = delegate
        
        setup()
    }
    
    convenience init(eventId: Int, delegate: EventsViewControllerDelegate?) {
        self.init(events: nil, delegate: delegate)
        eventDetailsId = eventId
        
        tableViewStateObservable.next(.loading)
        
        NetworkProvider.shared.eventDetails(with: eventId) { [weak self] response in
            switch response {
            case let .success(event):
                self?.lastEventObservable.next(event)
            case .error:
                self?.tableViewStateObservable.next(.error)
            }
        }
    }

    private func setup() {
        eventsListRefreshObservable.subscribeNext { [weak self] in
            NetworkProvider.shared.eventsList(with: 1) { [weak self] response in
                guard case .success(let events) = response, let firstEventId = events.elements.first?.id else {
                    self?.eventsListRefreshObservable.complete()
                    return
                }
                
                NetworkProvider.shared.eventDetails(with: firstEventId) { response in
                    if case .success(let event) = response {
                        self?.lastEventObservable.next(event)
                    }
                    
                    self?.eventsListRefreshObservable.complete()
                }
                
                self?.previousEventsObservable.next(events.elements.tail)
            }
        }
        .add(to: disposeBag)
        
        eventDetailsRefreshObservable.subscribeNext { [weak self] in
            guard let eventDetailsId = self?.eventDetailsId else {
                self?.eventDetailsRefreshObservable.complete()
                return
            }
            
            NetworkProvider.shared.eventDetails(with: eventDetailsId) { response in
                if case .success(let event) = response {
                    self?.lastEventObservable.next(event)
                }
                
                self?.eventDetailsRefreshObservable.complete()
            }
        }
        .add(to: disposeBag)
        
        lastEventObservable.subscribeNext(startsWithInitialValue: true) { [weak self] event in
            guard let weakSelf = self else { return }
            
            weakSelf.tableViewStateObservable.next(event == nil ? .error : .content)
            
            let carouselViewModel = CarouselEventPhotosCellViewModel(photos: event?.coverImages ?? [])
            weakSelf.carouselEventPhotosViewModelObservable.next(carouselViewModel)
            
            weakSelf.checkAttendance()
            weakSelf.notificationManager = NotificationManager(date: event?.date?.addingTimeInterval(-Constants.minimumTimeForReminder))
            
            if weakSelf.isReminderAllowed {
                weakSelf.notificationStateObservable.next(weakSelf.notificationManager.isNotificationActive ? .active : .notActive)
            } else {
                weakSelf.notificationStateObservable.next(.notVisible)
            }
        }
        .add(to: disposeBag)
        
        summaryCellDidTapObservable.subscribeNext { [weak self] in
            self?.summaryCellTapped()
        }
        .add(to: disposeBag)
        
        locationCellDidTapObservable.subscribeNext { [weak self] in
            self?.locationCellTapped()
        }
        .add(to: disposeBag)

        previousEventsCellDidSetObservable
            .withLatest(from: previousEventsObservable, combine: { event in event.1 })
            .subscribeNext(startsWithInitialValue: true) { [weak self] events in
                guard let weakSelf = self else { return }
                let subviewModel = PreviousEventsListCellViewModel(previousEvents: weakSelf.previousEventsObservable, refreshObservable: weakSelf.eventsListRefreshObservable, delegate: weakSelf.delegate)
                weakSelf.previousEventsViewModelObservable.next(subviewModel)
            }
            .add(to: disposeBag)
        
        speakerCellDidTapObservable.subscribeNext { [weak self] index in
            guard index != -1 else { return }
            self?.speakerCellTapped(with: index)
        }
        .add(to: disposeBag)
        
        lectureCellDidTapObservable.subscribeNext { [weak self] talk in
            guard let talk = talk else { return }
            self?.lectureCellTapped(with: talk)
        }
        .add(to: disposeBag)

        NotificationCenter
            .default
            .notification(Notification.Name.UIApplicationWillEnterForeground)
            .subscribeNext { [weak self] _ in
                guard let weakSelf = self else { return }
                if !weakSelf.isReminderAllowed {
                    weakSelf.notificationStateObservable.next(.notVisible)
                }
            }
            .add(to: disposeBag)

        guard let time = lastEventObservable
                            .value?
                            .date?
                            .addingTimeInterval(-Constants.minimumTimeForReminder)
                            .timeIntervalSince(Date()) else { return }
        Timer.scheduledTimer(timeInterval: time, target: self, selector: #selector(eventReminderTimeFinished), userInfo: nil, repeats: false)

        guard let eventLeftTime = lastEventObservable
                                    .value?
                                    .date?
                                    .timeIntervalSince(Date()) else { return }
        Timer.scheduledTimer(timeInterval: eventLeftTime, target: self, selector: #selector(eventFinished), userInfo: nil, repeats: false)

        FacebookManager.shared.facebookLoginObservable.subscribeNext { [weak self] in
            self?.checkAttendance()
        }
        .add(to: disposeBag)

        FacebookManager.shared.facebookLogoutObservable.subscribeNext { [weak self] in
            guard let weakSelf = self else { return }

            let state: AttendanceState = weakSelf.isEventOutdated ? .notAllowed : .notAttending
            weakSelf.attendanceStateObservable.next(state)
        }
        .add(to: disposeBag)
    }

    @objc private func eventReminderTimeFinished() {
        notificationStateObservable.next(.notVisible)
    }

    @objc private func eventFinished() {
        attendanceStateObservable.next(.notAllowed)
        eventDidFinishObservable.next(lastEventObservable.value)
    }
    
    private func checkAttendance() {
        guard let eventId = lastEventObservable.value?.facebook else { return }

        attendanceStateObservable.next(isEventOutdated ? .notAllowed : .loading)

        guard !isEventOutdated else { return }
        
        attendanceStateObservable.next(.loading)
        FacebookManager.shared.isUserAttending(toEventId: eventId) { [weak self] result in
            self?.attendanceStateObservable.next(result == .attending ? .attending : .notAttending)
        }
    }
    
    private func attendanceToFbState(_ attendance: AttendanceState) -> FacebookEventAttendance? {
        switch attendance {
        case .attending: return .attending
        case .notAttending: return .declined
        default: return nil
        }
    }
    
    @objc func attendButtonTapped() {
        guard !isEventOutdated else {
            delegate?.presentPhotoGalleryScreen(with: lastEventObservable.value?.photos ?? [], eventId: eventDetailsId)
            return
        }
        guard let eventId = lastEventObservable.value?.facebook, attendanceStateObservable.value != .loading else { return }
        guard FacebookManager.shared.isLoggedIn else {
            loginScreenObservable.next()
            return
        }
        
        let oldAttendance = attendanceStateObservable.value
        let newAttendance: AttendanceState = oldAttendance == .attending ? .notAttending : .attending
        
        attendanceStateObservable.next(.loading)
        FacebookManager.shared.changeEvent(attendanceTo: attendanceToFbState(newAttendance)!, forId: eventId) { [weak self] result in
            if result {
                self?.attendanceStateObservable.next(newAttendance)
            } else {
                self?.attendanceStateObservable.next(oldAttendance)
                self?.facebookAlertObservable.next(nil)
            }
        }
    }
    
    @objc func remindButtonTapped() {
        guard let formattedTime = lastEventObservable.value?.date?.stringTimeValue else { return }
        
        if notificationManager.isNotificationActive {
            notificationManager.cancelNotification()
            notificationStateObservable.next(notificationManager.isNotificationActive ? .active : .notActive)
        } else {
            let message = "\(localized("GENERAL_NOTIFICATION_WHERE")) \(formattedTime) \(localized("GENERAL_NOTIFICATION_ON")) \(lastEventObservable.value?.title ?? "")"
            
            notificationManager.succeededScheduleNotification(withMessage: message) { [weak self] activeNotification, permissionsGranted in
                if permissionsGranted {
                    self?.notificationStateObservable.next(activeNotification ? .active : .notActive)
                } else {
                    self?.notificationPermissionsNotGrantedObservable.next()
                }
            }
        }
    }
    
    private func summaryCellTapped() {
        delegate?.presentEventDetailsScreen(fromViewModel: self)
    }
    
    private func locationCellTapped() {
        guard let coordinates = lastEventObservable.value?.placeCoordinates else { return }
        MapHelper.openMaps(withCoordinates: coordinates, name: lastEventObservable.value?.placeName ?? lastEventObservable.value?.title)
    }
    
    private func speakerCellTapped(with index: Int) {
        guard let speaker = lastEventObservable.value?.talks[safe: index]?.speaker else { return }

        delegate?.presentSpeakerDetailsScreen(with: speaker.id)
    }
    
    private func lectureCellTapped(with talk: Talk) {
        delegate?.presentLectureScreen(with: talk)
    }
}
