//
//  OnboardingViewController.swift
//  LetSwift
//
//  Created by Marcin Chojnacki, Kinga Wilczek on 12.04.2017.
//  Copyright © 2017 Droids On Roids. All rights reserved.
//

import UIKit

protocol OnboardingViewControllerCoordinatorDelegate: class {
    func onboardingHasCompleted()
}

final class OnboardingViewController: UIViewController {

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet fileprivate weak var continueButton: UIButton!
    @IBOutlet private weak var onboardingPageControl: UIPageControl!

    fileprivate var viewModel: OnboardingViewControllerViewModel!
    
    convenience init(viewModel: OnboardingViewControllerViewModel) {
        self.init()
        self.viewModel = viewModel
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.delegate = self

        setupViewModel()
    }

    private func setupViewModel() {
        continueButton.addTarget(viewModel, action: #selector(OnboardingViewControllerViewModel.continueButtonTapped), for: .touchUpInside)

        viewModel.currentPageObservable.subscribe(onNext: { [unowned self] page in
            let xOffset = self.scrollView.contentOffset.x
            let singleWidth = self.scrollView.frame.size.width
            
            if xOffset >= 0 && xOffset <= self.scrollView.contentSize.width - singleWidth {
                let xPosition = CGFloat(page) * singleWidth

                self.scrollView.setContentOffset(CGPoint(x: xPosition, y: 0.0), animated: true)
                self.onboardingPageControl.currentPage = page
            }
        })

        viewModel.continueButtonTitleObservable.subscribe(startsWithInitialValue: true) { [unowned self] title in
            self.continueButton.setTitle(title, for: [])
        }
        
        viewModel.onboardingCardsObservable.subscribe(startsWithInitialValue: true)  { [unowned self] cards in
            DispatchQueue.main.async {
                self.setupScrollView(with: cards)
                self.onboardingPageControl.numberOfPages = cards.count
            }
        }
    }
    
    private func setupScrollView(with cards: [OnboardingCardModel]) {
        let frameSize = scrollView.frame.size

        cards.enumerated().forEach { index, card in
            let frame = CGRect(origin: CGPoint(x: frameSize.width * CGFloat(index), y: 0.0),
                               size: frameSize)
            
            let subview = OnboardingCardView(frame: frame)
            subview.setData(with: card)
            
            scrollView.addSubview(subview)
        }

        scrollView.contentSize = CGSize(width: frameSize.width * CGFloat(cards.count),
                                        height: frameSize.height)
    }
}

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        viewModel.swipeDidFinish(with: Int(scrollView.contentOffset.x / scrollView.frame.size.width))
    }
}
