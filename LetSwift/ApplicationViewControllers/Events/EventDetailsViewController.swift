//
//  EventDetailsViewController.swift
//  LetSwift
//
//  Created by Marcin Chojnacki on 02.05.2017.
//  Copyright © 2017 Droids On Roids. All rights reserved.
//

import UIKit

final class EventDetailsViewController: CommonEventViewController {
    
    override var allCells: [EventCellIdentifier] {
        return [.carouselEventPhotos, .attend, .eventSummary, .eventLocation, .eventTime,
                .speakerCardHeaderCell]
    }
    
    override var refreshObservable: Observable<Void>? {
        return viewModel.eventDetailsRefreshObservable
    }
    
    override var viewControllerTitleKey: String? {
        return "EVENTS_DETAILS_TITLE"
    }
    
    override var shouldShowUserIcon: Bool {
        return false
    }
    
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }
    
    override func dispatchCellSetup(element: EventCellIdentifier, cell: UITableViewCell, index: Int) {
        super.dispatchCellSetup(element: element, cell: cell, index: index)

        switch element {
        case .eventSummary:
            (cell as! EventSummaryTableViewCell).isClickable = false
            
        case .carouselEventPhotos:
            self.setup(carouselCell: cell as! CarouselEventPhotosTableViewCell)
        
        case .speakerCardCell:
            self.setup(speakerCardCell: cell as! SpeakerCardCell, index: index)

        default: break
        }
    }

    private func setup() {
        tableView.registerCells([EventCellIdentifier.speakerCardCell.rawValue, EventCellIdentifier.speakersToBeAnnouncedCell.rawValue])

        reactiveSetup()
    }

    private func reactiveSetup() {
        viewModel.lastEventObservable.subscribeNext(startsWithInitialValue: true) { [weak self] event in
            guard let event = event else { return }
            let speakersTalks = [EventCellIdentifier](repeating: .speakerCardCell, count: event.talks.count)
            self?.bindableCells.remove(updated: false) {
                [.speakerCardCell, .speakersToBeAnnouncedCell].contains($0)
            }
            self?.bindableCells.append(speakersTalks.isEmpty ? [.speakersToBeAnnouncedCell] : speakersTalks)
            
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
        .add(to: disposeBag)
    }
    
    private func setup(carouselCell cell: CarouselEventPhotosTableViewCell) {
        viewModel.carouselEventPhotosViewModelObservable.subscribeNext(startsWithInitialValue: true) { viewModel in
            cell.viewModel = viewModel
        }
        .add(to: disposeBag)
    }
    
    private func setup(speakerCardCell cell: SpeakerCardCell, index: Int) {
        viewModel.lastEventObservable
                .filter { !($0?.talks.isEmpty ?? true) }
                .subscribeNext(startsWithInitialValue: true) { [weak self] event in
                    guard let weakSelf = self, let event = event else { return }

                    let speakerIndex = weakSelf.bindableCells.values.count - index

                    guard event.talks.count >= speakerIndex else { return }

                    let talkId = event.talks.count - speakerIndex
                    let talk = event.talks[talkId]
                    cell.loadData(with: talk)

                    cell.addTapListeners(speaker: { [weak self] in
                        self?.viewModel.speakerCellDidTapObservable.next(talkId)
                    }, readMore: { [weak self] in
                        self?.viewModel.lectureCellDidTapObservable.next(talkId)
                    })
                }
                .add(to: disposeBag)
    }
}
