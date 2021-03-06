//
//  SingleSubredditViewController.swift
//  Slide for Reddit
//
//  Created by Carlos Crane on 12/22/16.
//  Copyright © 2016 Haptic Apps. All rights reserved.
//

import Anchorage
import Embassy
import MaterialComponents.MDCActivityIndicator
import MKColorPicker
import RealmSwift
import reddift
import RLBAlertsPickers
import SDWebImage
import SloppySwiper
import YYText
import UIKit
import SDCAlertView

// MARK: - Base
class SingleSubredditViewController: MediaViewController, UINavigationControllerDelegate {

    override var prefersStatusBarHidden: Bool {
        return SettingValues.fullyHideNavbar
    }

    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(spacePressed)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(spacePressed)),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(spacePressedUp)),
            UIKeyCommand(input: "s", modifierFlags: .command, action: #selector(search), discoverabilityTitle: "Search"),
            UIKeyCommand(input: "p", modifierFlags: .command, action: #selector(hideReadPosts), discoverabilityTitle: "Hide read posts"),
            UIKeyCommand(input: "r", modifierFlags: .command, action: #selector(refresh(_:)), discoverabilityTitle: "Reload"),
        ]
    }
    
    var navbarEnabled: Bool {
        return true
    }

    var toolbarEnabled: Bool {
        return true
    }

    let maxHeaderHeight: CGFloat = 120
    let minHeaderHeight: CGFloat = 56
    public var inHeadView: UIView?
    var lastTopItem: Int = 0
    
    let margin: CGFloat = 10
    let cellsPerRow = 3
    var readLaterCount: Int {
        return ReadLater.readLaterIDs.allValues.filter { (value) -> Bool in
                if sub == "all" || sub == "frontpage" { return true }
                guard let valueStr = value as? String else { return false }
                return valueStr.lowercased() == sub.lowercased()
                }.count
    }
    
    var panGesture: UIPanGestureRecognizer!
    var translatingCell: LinkCellView?

    var times = 0
    var startTime = Date()

    var parentController: MainViewController?
    var accentChosen: UIColor?
    var primaryChosen: UIColor?

    var isModal = false
    var offline = false

    var isAccent = false

    var isCollapsed = false
    var isHiding = false
    var isToolbarHidden = false

    var oldY = CGFloat(0)

    var links: [RSubmission] = []
    var paginator = Paginator()
    var sub: String
    var session: Session?
    var tableView: UICollectionView!
    var single: Bool = false

    var loaded = false
    var sideView: UIView = UIView()
    var subb: UIButton = UIButton()
    var subInfo: Subreddit?
    var flowLayout: WrappingFlowLayout = WrappingFlowLayout.init()

    static var firstPresented = true
    static var cellVersion = 0 {
        didSet {
            PagingCommentViewController.savedComment = nil
        }
    }
    var swiper: SloppySwiper?

    var more = UIButton()

    var lastY: CGFloat = CGFloat(0)
    var lastYUsed = CGFloat(0)

    var listingId: String = "" //a random id for use in Realm

    var fab: UIButton?

    var first = true
    var indicator: MDCActivityIndicator?

    var searchText: String?

    var loading = false
    var nomore = false

    var showing = false

    var sort = SettingValues.defaultSorting
    var time = SettingValues.defaultTimePeriod

    var refreshControl: UIRefreshControl!

    var realmListing: RListing?
    var hasHeader = false
    var subLinks = [SubLinkItem]()

    var oldsize = CGFloat(0)

    init(subName: String, parent: MainViewController) {
        sub = subName
        self.parentController = parent

        super.init(nibName: nil, bundle: nil)
        self.sort = SettingValues.getLinkSorting(forSubreddit: self.sub)
        self.time = SettingValues.getTimePeriod(forSubreddit: self.sub)
    }

    init(subName: String, single: Bool) {
        sub = subName
        self.single = true
        super.init(nibName: nil, bundle: nil)
        self.sort = SettingValues.getLinkSorting(forSubreddit: self.sub)
        self.time = SettingValues.getTimePeriod(forSubreddit: self.sub)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        CachedTitle.titles.removeAll()

        flowLayout.delegate = self
        self.tableView = UICollectionView(frame: CGRect.zero, collectionViewLayout: flowLayout)
        self.view = UIView.init(frame: CGRect.zero)
        self.view.addSubview(tableView)

        tableView.verticalAnchors == view.verticalAnchors
        tableView.horizontalAnchors == view.safeHorizontalAnchors

        panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.panCell))
        panGesture.direction = .horizontal
        panGesture.delegate = self
        self.tableView.addGestureRecognizer(panGesture)
        if single && navigationController != nil {
            panGesture.require(toFail: navigationController!.interactivePopGestureRecognizer!)
        }
        
        if single {
            self.edgesForExtendedLayout = UIRectEdge.all
        } else {
            self.edgesForExtendedLayout = []
        }
        
        self.extendedLayoutIncludesOpaqueBars = true

        self.tableView.delegate = self
        self.tableView.dataSource = self
        refreshControl = UIRefreshControl()

        if !(navigationController is TapBehindModalViewController) {
            inHeadView = UIView().then {
                $0.backgroundColor = ColorUtil.getColorForSub(sub: sub, true)
                if SettingValues.fullyHideNavbar {
                    $0.backgroundColor = .clear
                }
            }
            self.view.addSubview(inHeadView!)
            inHeadView!.isHidden = UIDevice.current.orientation.isLandscape

            inHeadView!.topAnchor == view.topAnchor
            inHeadView!.horizontalAnchors == view.horizontalAnchors
            inHeadView!.heightAnchor == (UIApplication.shared.statusBarView?.frame.size.height ?? 0)
        }

        reloadNeedingColor()
        self.flowLayout.reset(modal: self.presentingViewController != nil)
        tableView.reloadData()
        self.automaticallyAdjustsScrollViewInsets = false
        
        if #available(iOS 11.0, *) {
            self.tableView.contentInsetAdjustmentBehavior = .never
        }
    }
    
    func reTheme() {
        self.reloadNeedingColor()
        flowLayout.reset(modal: presentingViewController != nil)
        CachedTitle.titles.removeAll()
        LinkCellImageCache.initialize()
        self.tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if single && !isModal && !(self.navigationController!.delegate is SloppySwiper) {
            swiper = SloppySwiper.init(navigationController: self.navigationController!)
            self.navigationController!.delegate = swiper!
            for view in view.subviews {
                if view is UIScrollView {
                    let scrollView = view as! UIScrollView
                    swiper!.panRecognizer.require(toFail: scrollView.panGestureRecognizer)
                    break
                }
            }
        }

        server?.stop()
        loop?.stop()

        first = false
        tableView.delegate = self

        if single {
            setupBaseBarColors()
        }
        
        if !loaded {
            showUI()
        }
        self.view.backgroundColor = ColorUtil.theme.backgroundColor
        
        self.navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = false
        splitViewController?.navigationController?.navigationBar.isTranslucent = false
        splitViewController?.navigationController?.setNavigationBarHidden(true, animated: false)
        if let bar = splitViewController?.navigationController?.navigationBar {
            bar.heightAnchor == 0
        }

        if single {
            navigationController?.navigationBar.barTintColor = ColorUtil.getColorForSub(sub: sub, true)
            if let interactiveGesture = self.navigationController?.interactivePopGestureRecognizer {
                self.tableView.panGestureRecognizer.require(toFail: interactiveGesture)
            }
        }
        
        navigationController?.navigationBar.tintColor = SettingValues.reduceColor ? ColorUtil.theme.fontColor : UIColor.white
        
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.splitViewController?.navigationController?.navigationBar.shadowImage = UIImage()

        if single {
            navigationController?.navigationBar.barTintColor = ColorUtil.getColorForSub(sub: sub, true)
        }
        
        navigationController?.toolbar.barTintColor = ColorUtil.theme.backgroundColor
        navigationController?.toolbar.tintColor = ColorUtil.theme.fontColor

        inHeadView?.isHidden = UIDevice.current.orientation.isLandscape
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if toolbarEnabled && !MainViewController.isOffline {
            if single {
                navigationController?.setToolbarHidden(false, animated: false)
            } else {
                parentController?.menuNav?.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - (parentController?.menuNav?.bottomOffset ?? 64), width: parentController?.menuNav?.view.frame.width ?? 0, height: parentController?.menuNav?.view.frame.height ?? 0)
            }
            self.isToolbarHidden = false
            if fab == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.setupFab(self.view.bounds.size)
                }
            } else {
                show(true)
            }
        } else {
            if single {
                navigationController?.setToolbarHidden(true, animated: false)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if cell is AutoplayBannerLinkCellView {
            (cell as! AutoplayBannerLinkCellView).doLoadVideo()
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if self.view.bounds.width != oldsize {
            oldsize = self.view.bounds.width
            flowLayout.reset(modal: presentingViewController != nil)
            tableView.reloadData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        for index in tableView.indexPathsForVisibleItems {
            if let cell = tableView.cellForItem(at: index) as? LinkCellView {
                cell.endVideos()
            }
        }

        if single {
            UIApplication.shared.statusBarView?.backgroundColor = .clear
        }
        if fab != nil {
            UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                self.fab?.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)
            }, completion: { _ in
                self.fab?.removeFromSuperview()
                self.fab = nil
            })
        }
        
        if let session = (UIApplication.shared.delegate as? AppDelegate)?.session {
            if AccountController.isLoggedIn && AccountController.isGold && !History.currentSeen.isEmpty {
                do {
                    try session.setVisited(names: History.currentSeen) { (result) in
                        print(result)
                        History.currentSeen.removeAll()
                    }
                } catch let error {
                    print(error)
                }
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.fab?.removeFromSuperview()
        self.fab = nil
        
        self.setupFab(size)

        inHeadView?.isHidden = UIDevice.current.orientation.isLandscape

        coordinator.animate(
            alongsideTransition: { [unowned self] _ in
                self.flowLayout.reset(modal: self.presentingViewController != nil)
                self.tableView.reloadData()
                self.view.setNeedsLayout()
                //todo content offset
            }, completion: nil
        )

//        if self.viewIfLoaded?.window != nil {
//            tableView.reloadData()
//        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if ColorUtil.theme.isLight && SettingValues.reduceColor {
            return .default
        } else {
            return .lightContent
        }
    }
    
    static func getHeightFromAspectRatio(imageHeight: CGFloat, imageWidth: CGFloat, viewWidth: CGFloat) -> CGFloat {
        let ratio = imageHeight / imageWidth
        return viewWidth * ratio
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if fab != nil {
            fab?.removeFromSuperview()
            fab = nil
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentY = scrollView.contentOffset.y

        if !SettingValues.pinToolbar {
            if currentY > lastYUsed && currentY > 60 {
                if navigationController != nil && !isHiding && !isToolbarHidden && !(scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)) {
                    hideUI(inHeader: true)
                } else if fab != nil && !fab!.isHidden && !isHiding {
                    UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                        self.fab?.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)
                    }, completion: { _ in
                        self.fab?.isHidden = true
                        self.isHiding = false
                    })
                }
            } else if (currentY < lastYUsed - 15 || currentY < 100) && !isHiding && navigationController != nil && (isToolbarHidden) {
                showUI()
            }
        }
        
        lastYUsed = currentY
        lastY = currentY
    }
    
    func hideUI(inHeader: Bool) {
        isHiding = true
        if navbarEnabled {
            (navigationController)?.setNavigationBarHidden(true, animated: true)
        }
        
        UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
            self.fab?.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)
        }, completion: { _ in
            self.fab?.isHidden = true
            self.isHiding = false
        })
        
        if single {
            navigationController?.setToolbarHidden(true, animated: true)
        } else {
            if let parent = self.parentController, parent.menu.superview != nil, let topView = parent.menuNav?.topView {
                parent.menu.deactivateImmediateConstraints()
                parent.menu.topAnchor == topView.topAnchor - 10
                parent.menu.widthAnchor == 56
                parent.menu.heightAnchor == 56
                parent.menu.leftAnchor == topView.leftAnchor
                
                parent.more.deactivateImmediateConstraints()
                parent.more.topAnchor == topView.topAnchor - 10
                parent.more.widthAnchor == 56
                parent.more.heightAnchor == 56
                parent.more.rightAnchor == topView.rightAnchor
            }
            UIView.animate(withDuration: 0.25) {
                self.parentController?.menuNav?.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - (SettingValues.totallyCollapse ? 0 : ((self.parentController?.menuNav?.bottomOffset ?? 56) / 2)), width: self.parentController?.menuNav?.view.frame.width ?? 0, height: self.parentController?.menuNav?.view.frame.height ?? 0)
                self.parentController?.menu.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                self.parentController?.more.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            }
            //            if !single && parentController != nil {
            //                parentController!.drawerButton.isHidden = false
            //            }
        }
        self.isToolbarHidden = true
    }

    func showUI(_ disableBottom: Bool = false) {
        if navbarEnabled {
            (navigationController)?.setNavigationBarHidden(false, animated: true)
        }
        
        if self.fab?.superview != nil {
            self.fab?.isHidden = false
            self.fab?.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)
            
            UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                self.fab?.transform = CGAffineTransform.identity
            })
        }

        if single && !MainViewController.isOffline {
            navigationController?.setToolbarHidden(false, animated: true)
        } else if !disableBottom {
            UIView.animate(withDuration: 0.25) {
                if let parent = self.parentController {
                    if parent.menu.superview != nil, let topView = parent.menuNav?.topView {
                        parent.menu.deactivateImmediateConstraints()
                        parent.menu.topAnchor == topView.topAnchor
                        parent.menu.widthAnchor == 56
                        parent.menu.heightAnchor == 56
                        parent.menu.leftAnchor == topView.leftAnchor

                        parent.more.deactivateImmediateConstraints()
                        parent.more.topAnchor == topView.topAnchor
                        parent.more.widthAnchor == 56
                        parent.more.heightAnchor == 56
                        parent.more.rightAnchor == topView.rightAnchor
                    }

                    parent.menuNav?.view.frame = CGRect(x: 0, y: (UIScreen.main.bounds.height - (parent.menuNav?.bottomOffset ?? 0)), width: parent.menuNav?.view.frame.width ?? 0, height: parent.menuNav?.view.frame.height ?? 0)
                    parent.menu.transform = CGAffineTransform(scaleX: 1, y: 1)
                    parent.more.transform = CGAffineTransform(scaleX: 1, y: 1)
                }
            }
        }
        self.isToolbarHidden = false
    }

    func show(_ animated: Bool = true) {
        if fab != nil && (fab!.isHidden || fab!.superview == nil) {
            if animated {
                if fab!.superview == nil {
                    if single {
                        self.navigationController?.toolbar.addSubview(fab!)
                    } else {
                        parentController?.toolbar?.addSubview(fab!)
                    }
                }
                self.fab!.isHidden = false
                self.fab?.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)

                UIView.animate(withDuration: 0.3, animations: { () -> Void in
                    self.fab?.transform = CGAffineTransform.identity
                })
            } else {
                self.fab!.isHidden = false
            }
        }
    }

    func hideFab(_ animated: Bool = true) {
        if self.fab != nil {
            if animated {
                UIView.animate(withDuration: 0.3, animations: { () -> Void in
                    self.fab!.alpha = 0
                }, completion: { _ in
                    self.fab!.isHidden = true
                })
            } else {
                self.fab!.isHidden = true
            }
        }
    }

    func setupFab(_ size: CGSize) {
        addNewFab(size)
    }
    
    func addNewFab(_ size: CGSize) {
        if self.fab != nil {
            self.fab!.removeFromSuperview()
            self.fab = nil
        }
        if !MainViewController.isOffline && !SettingValues.hiddenFAB {
            self.fab = UIButton(frame: CGRect.init(x: (size.width / 2) - 70, y: -20, width: 140, height: 45))
            self.fab!.backgroundColor = ColorUtil.accentColorForSub(sub: sub)
            self.fab!.accessibilityHint = sub
            self.fab!.layer.cornerRadius = 22.5
            self.fab!.clipsToBounds = true
            let title = "  " + SettingValues.fabType.getTitleShort()
            self.fab!.setTitle(title, for: .normal)
            self.fab!.leftImage(image: (UIImage.init(named: SettingValues.fabType.getPhoto())?.navIcon(true))!, renderMode: UIImage.RenderingMode.alwaysOriginal)
            self.fab!.elevate(elevation: 2)
            self.fab!.titleLabel?.textAlignment = .center
            self.fab!.titleLabel?.font = UIFont.systemFont(ofSize: 14)
            
            let width = title.size(with: self.fab!.titleLabel!.font).width + CGFloat(65)
            self.fab!.frame = CGRect.init(x: (size.width / 2) - (width / 2), y: -20, width: width, height: CGFloat(45))
            
            self.fab!.titleEdgeInsets = UIEdgeInsets.init(top: 0, left: 20, bottom: 0, right: 20)
            if single {
                self.navigationController?.toolbar.addSubview(self.fab!)
            } else {
                self.parentController?.toolbar?.addSubview(self.fab!)
                self.parentController?.menuNav?.callbacks.didBeginPanning = {
                    if !(self.fab?.isHidden ?? true) && !self.isHiding {
                        UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                            self.fab?.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)
                        }, completion: { _ in
                            self.fab?.isHidden = true
                            self.isHiding = false
                        })
                    }
                }
                self.parentController?.menuNav?.callbacks.didCollapse = {
                    self.fab?.isHidden = false
                    self.fab?.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)
                    
                    UIView.animate(withDuration: 0.25, delay: 0.25, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                        self.fab?.transform = CGAffineTransform.identity
                    }, completion: { _ in
                    })
                }
            }

            self.fab?.transform = CGAffineTransform.init(scaleX: 0.001, y: 0.001)
            UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                self.fab?.transform = CGAffineTransform.identity
            }, completion: { (_)  in
                self.fab?.addTarget(self, action: #selector(self.doFabActions), for: .touchUpInside)
                self.fab?.addLongTapGestureRecognizer {
                    self.changeFab()
                }
            })
        }
    }

    @objc func doFabActions() {
        if UserDefaults.standard.bool(forKey: "FAB_SHOWN") == false {
            let a = UIAlertController(title: "Subreddit Action Button", message: "This is the subreddit action button!\n\nThis button's actions can be customized by long pressing on it at any time, and this button can be removed completely in Settings > General.", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Change action", style: .default, handler: { (_) in
                UserDefaults.standard.set(true, forKey: "FAB_SHOWN")
                UserDefaults.standard.synchronize()
                self.changeFab()
            }))
            a.addAction(UIAlertAction(title: "Hide button", style: .default, handler: { (_) in
                SettingValues.hiddenFAB = true
                UserDefaults.standard.set(true, forKey: SettingValues.pref_hiddenFAB)
                UserDefaults.standard.set(true, forKey: "FAB_SHOWN")
                UserDefaults.standard.synchronize()
                self.setupFab(self.view.bounds.size)
            }))
            a.addAction(UIAlertAction(title: "Continue", style: .default, handler: { (_) in
                UserDefaults.standard.set(true, forKey: "FAB_SHOWN")
                UserDefaults.standard.synchronize()
                self.doFabActions()
            }))
            
            self.present(a, animated: true, completion: nil)
        } else {
            switch SettingValues.fabType {
            case .SIDEBAR:
                self.doDisplaySidebar()
            case .NEW_POST:
                self.newPost(self.fab!)
            case .SHADOWBOX:
                self.shadowboxMode()
            case .RELOAD:
                self.refresh()
            case .HIDE_READ:
                self.hideReadPosts()
            case .HIDE_PERMANENTLY:
                self.hideReadPostsPermanently()
            case .GALLERY:
                self.galleryMode()
            case .SEARCH:
                self.search()
            }
        }
    }
    
    var headerImage: URL?
    
    func loadBubbles() {
        self.subLinks.removeAll()
        if self.sub == ("all") || self.sub == ("frontpage") || self.sub == ("popular") || self.sub == ("friends") || self.sub.lowercased() == ("myrandom") || self.sub.lowercased() == ("random") || self.sub.lowercased() == ("randnsfw") || self.sub.hasPrefix("/m/") || self.sub.contains("+") {
            return
        }
        do {
            try (UIApplication.shared.delegate as! AppDelegate).session?.getStyles(sub, completion: { (result) in
                switch result {
                case .failure(let error):
                    print(error)
                    return
                case .success(let r):
                    if let baseData = r as? JSONDictionary, let data = baseData["data"] as? [String: Any] {
                        if let content = data["content"] as? [String: Any],
                            let widgets = content["widgets"] as? [String: Any],
                            let items = widgets["items"] as? [String: Any] {
                            for item in items.values {
                                if let body = item as? [String: Any] {
                                    if let kind = body["kind"] as? String, kind == "menu" {
                                        if let data = body["data"] as? JSONArray {
                                            for link in data {
                                                if let children = link["children"] as? JSONArray {
                                                    for subItem in children {
                                                        if let content = subItem as? JSONDictionary {
                                                            self.subLinks.append(SubLinkItem(content["text"] as? String, link: URL(string: (content["url"] as! String).decodeHTML())))
                                                        }
                                                    }
                                                } else {
                                                    self.subLinks.append(SubLinkItem(link["text"] as? String, link: URL(string: (link["url"] as! String).decodeHTML())))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if let styles = data["style"] as? [String: Any] {
                            if let headerUrl = styles["bannerBackgroundImage"] as? String {
                                self.headerImage = URL(string: headerUrl.unescapeHTML)
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        self.hasHeader = true
                        if self.loaded && !self.loading {
                            self.flowLayout.reset(modal: self.presentingViewController != nil)
                            self.tableView.reloadData()
                            if UIDevice.current.userInterfaceIdiom != .pad {
                                var newOffset = self.tableView.contentOffset
                                newOffset.y -= self.headerHeight(false)
                                self.tableView.setContentOffset(newOffset, animated: false)
                            }
                        }
                    }
                }
            })
        } catch {
        }
    }
    
    func changeFab() {
        if !UserDefaults.standard.bool(forKey: "FAB_SHOWN") {
            UserDefaults.standard.set(true, forKey: "FAB_SHOWN")
            UserDefaults.standard.synchronize()
        }
        
        let actionSheetController: UIAlertController = UIAlertController(title: "Change button type", message: "", preferredStyle: .alert)

        actionSheetController.addCancelButton()

        for t in SettingValues.FabType.cases {
            let saveActionButton: UIAlertAction = UIAlertAction(title: t.getTitle(), style: .default) { _ -> Void in
                UserDefaults.standard.set(t.rawValue, forKey: SettingValues.pref_fabType)
                SettingValues.fabType = t
                self.setupFab(self.view.bounds.size)
            }
            actionSheetController.addAction(saveActionButton)
        }

        self.present(actionSheetController, animated: true, completion: nil)
    }

    var lastVersion = 0
    
    func reloadNeedingColor() {
        tableView.backgroundColor = ColorUtil.theme.backgroundColor
        inHeadView?.backgroundColor = ColorUtil.getColorForSub(sub: sub, true)
        if SettingValues.fullyHideNavbar {
            inHeadView?.backgroundColor = .clear
        }

        refreshControl.tintColor = ColorUtil.theme.fontColor
        refreshControl.attributedTitle = NSAttributedString(string: "")
        refreshControl.addTarget(self, action: #selector(self.drefresh(_:)), for: UIControl.Event.valueChanged)
        tableView.addSubview(refreshControl) // not required when using UITableViewController
        tableView.alwaysBounceVertical = true
        
        self.automaticallyAdjustsScrollViewInsets = false

        // TODO: Can just use .self instead of .classForCoder()
        self.tableView.register(BannerLinkCellView.classForCoder(), forCellWithReuseIdentifier: "banner\(SingleSubredditViewController.cellVersion)")
        self.tableView.register(AutoplayBannerLinkCellView.classForCoder(), forCellWithReuseIdentifier: "autoplay\(SingleSubredditViewController.cellVersion)")
        self.tableView.register(ThumbnailLinkCellView.classForCoder(), forCellWithReuseIdentifier: "thumb\(SingleSubredditViewController.cellVersion)")
        self.tableView.register(TextLinkCellView.classForCoder(), forCellWithReuseIdentifier: "text\(SingleSubredditViewController.cellVersion)")
        self.tableView.register(LoadingCell.classForCoder(), forCellWithReuseIdentifier: "loading")
        self.tableView.register(ReadLaterCell.classForCoder(), forCellWithReuseIdentifier: "readlater")
        self.tableView.register(PageCell.classForCoder(), forCellWithReuseIdentifier: "page")
        self.tableView.register(LinksHeaderCellView.classForCoder(), forCellWithReuseIdentifier: "header")
        lastVersion = SingleSubredditViewController.cellVersion

        var top = 68
        if #available(iOS 11.0, *) {
            top += 20
        }
 
        self.tableView.contentInset = UIEdgeInsets.init(top: CGFloat(top), left: 0, bottom: 65, right: 0)

        session = (UIApplication.shared.delegate as! AppDelegate).session

        if (SingleSubredditViewController.firstPresented && !single && self.links.count == 0) || (self.links.count == 0 && !single && !SettingValues.subredditBar) {
            load(reset: true)
            SingleSubredditViewController.firstPresented = false
        }

        self.sort = SettingValues.getLinkSorting(forSubreddit: self.sub)
        self.time = SettingValues.getTimePeriod(forSubreddit: self.sub)
        
        let offline = MainViewController.isOffline

        if single && !offline {
            let sort = UIButton.init(type: .custom)
            sort.setImage(UIImage.init(named: "ic_sort_white")?.navIcon(), for: UIControl.State.normal)
            sort.addTarget(self, action: #selector(self.showSortMenu(_:)), for: UIControl.Event.touchUpInside)
            sort.frame = CGRect.init(x: 0, y: 0, width: 25, height: 25)
            let sortB = UIBarButtonItem.init(customView: sort)

            subb = UIButton.init(type: .custom)
            subb.setImage(UIImage.init(named: Subscriptions.subreddits.contains(sub) ? "subbed" : "addcircle")?.navIcon(), for: UIControl.State.normal)
            subb.addTarget(self, action: #selector(self.subscribeSingle(_:)), for: UIControl.Event.touchUpInside)
            subb.frame = CGRect.init(x: 0, y: 0, width: 25, height: 25)
            let subbB = UIBarButtonItem.init(customView: subb)

            let info = UIButton.init(type: .custom)
            info.setImage(UIImage.init(named: "info")?.toolbarIcon(), for: UIControl.State.normal)
            info.addTarget(self, action: #selector(self.doDisplaySidebar), for: UIControl.Event.touchUpInside)
            info.frame = CGRect.init(x: 0, y: 0, width: 25, height: 25)
            let infoB = UIBarButtonItem.init(customView: info)

            more = UIButton.init(type: .custom)
            more.setImage(UIImage.init(named: "moreh")?.menuIcon(), for: UIControl.State.normal)
            more.addTarget(self, action: #selector(self.showMoreNone(_:)), for: UIControl.Event.touchUpInside)
            more.frame = CGRect.init(x: 0, y: 0, width: 25, height: 25)
            let moreB = UIBarButtonItem.init(customView: more)
            
            navigationItem.rightBarButtonItems = [sortB]
            let flexButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
            
            toolbarItems = [infoB, flexButton, moreB]
            title = sub

            if !loaded {
                do {
                    try (UIApplication.shared.delegate as! AppDelegate).session?.about(sub, completion: { (result) in
                        switch result {
                        case .failure:
                            print(result.error!.description)
                            DispatchQueue.main.async {
                                if self.sub == ("all") || self.sub == ("frontpage") || self.sub == ("popular") || self.sub == ("friends") || self.sub.lowercased() == ("myrandom") || self.sub.lowercased() == ("random") || self.sub.lowercased() == ("randnsfw") || self.sub.hasPrefix("/m/") || self.sub.contains("+") {
                                    self.load(reset: true)
                                    self.loadBubbles()
                                } else {
                                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                                        let alert = UIAlertController.init(title: "Subreddit not found", message: "r/\(self.sub) could not be found, is it spelled correctly?", preferredStyle: .alert)
                                        alert.addAction(UIAlertAction.init(title: "Close", style: .default, handler: { (_) in
                                            self.navigationController?.popViewController(animated: true)
                                            self.dismiss(animated: true, completion: nil)
                                            
                                        }))
                                        self.present(alert, animated: true, completion: nil)
                                    }
                                    
                                }
                            }
                        case .success(let r):
                            self.subInfo = r
                            DispatchQueue.main.async {
                                if self.subInfo!.over18 && !SettingValues.nsfwEnabled {
                                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                                        let alert = UIAlertController.init(title: "r/\(self.sub) is NSFW", message: "You must log into Reddit and enable NSFW content at Reddit.com to view this subreddit", preferredStyle: .alert)
                                        alert.addAction(UIAlertAction.init(title: "Close", style: .default, handler: { (_) in
                                            self.navigationController?.popViewController(animated: true)
                                            self.dismiss(animated: true, completion: nil)
                                        }))
                                        self.present(alert, animated: true, completion: nil)
                                    }
                                } else {
                                    if self.sub != ("all") && self.sub != ("frontpage") && !self.sub.hasPrefix("/m/") {
                                        if SettingValues.saveHistory {
                                            if SettingValues.saveNSFWHistory && self.subInfo!.over18 {
                                                Subscriptions.addHistorySub(name: AccountController.currentName, sub: self.subInfo!.displayName)
                                            } else if !self.subInfo!.over18 {
                                                Subscriptions.addHistorySub(name: AccountController.currentName, sub: self.subInfo!.displayName)
                                            }
                                        }
                                    }
                                    self.load(reset: true)
                                    self.loadBubbles()
                                }
                                
                            }
                        }
                    })
                } catch {
                }
            }
        } else if offline && single && !loaded {
            title = sub
            self.navigationController?.setToolbarHidden(true, animated: false)
            self.load(reset: true)
        }
    }

    func exit() {
        self.navigationController?.popViewController(animated: true)
        if self.navigationController!.modalPresentationStyle == .pageSheet {
            self.navigationController!.dismiss(animated: true, completion: nil)
        }
    }

    func doDisplayMultiSidebar(_ sub: Multireddit) {
        VCPresenter.presentModally(viewController: ManageMultireddit(multi: sub, reloadCallback: {
            self.refresh()
        }), self)
    }

    @objc func subscribeSingle(_ selector: AnyObject) {
        if subChanged && !Subscriptions.isSubscriber(sub) || Subscriptions.isSubscriber(sub) {
            //was not subscriber, changed, and unsubscribing again
            Subscriptions.unsubscribe(sub, session: session!)
            subChanged = false
            BannerUtil.makeBanner(text: "Unsubscribed", color: ColorUtil.accentColorForSub(sub: sub), seconds: 3, context: self, top: true)
            subb.setImage(UIImage.init(named: "addcircle")?.navIcon(), for: UIControl.State.normal)
        } else {
            let alrController = UIAlertController.init(title: "Follow r/\(sub)", message: nil, preferredStyle: .alert)
            if AccountController.isLoggedIn {
                let somethingAction = UIAlertAction(title: "Subscribe", style: UIAlertAction.Style.default, handler: { (_: UIAlertAction!) in
                    Subscriptions.subscribe(self.sub, true, session: self.session!)
                    self.subChanged = true
                    BannerUtil.makeBanner(text: "Subscribed to r/\(self.sub)", color: ColorUtil.accentColorForSub(sub: self.sub), seconds: 3, context: self, top: true)
                    self.subb.setImage(UIImage.init(named: "subbed")?.navIcon(), for: UIControl.State.normal)
                })
                alrController.addAction(somethingAction)
            }

            let somethingAction = UIAlertAction(title: "Casually subscribe", style: UIAlertAction.Style.default, handler: { (_: UIAlertAction!) in
                Subscriptions.subscribe(self.sub, false, session: self.session!)
                self.subChanged = true
                BannerUtil.makeBanner(text: "r/\(self.sub) added to your subreddit list", color: ColorUtil.accentColorForSub(sub: self.sub), seconds: 3, context: self, top: true)
                self.subb.setImage(UIImage.init(named: "subbed")?.navIcon(), for: UIControl.State.normal)
            })
            
            alrController.addAction(somethingAction)
            alrController.addCancelButton()

            self.present(alrController, animated: true, completion: {})

        }

    }

    func displayMultiredditSidebar() {
        do {
            try (UIApplication.shared.delegate as! AppDelegate).session?.getMultireddit(Multireddit.init(name: sub.substring(3, length: sub.length - 3), user: AccountController.currentName), completion: { (result) in
                switch result {
                case .success(let r):
                    DispatchQueue.main.async {
                        self.doDisplayMultiSidebar(r)
                    }
                default:
                    DispatchQueue.main.async {
                        BannerUtil.makeBanner(text: "Multireddit information not found", color: GMColor.red500Color(), seconds: 3, context: self)
                    }
                }

            })
        } catch {
        }
    }

    @objc func hideReadPosts() {
        var indexPaths: [IndexPath] = []

        var index = 0
        var count = 0
        self.lastTopItem = 0
        for submission in links {
            if History.getSeen(s: submission) {
                indexPaths.append(IndexPath(row: count, section: 0))
                links.remove(at: index)
            } else {
                index += 1
            }
            count += 1
        }

        //todo save realm
        DispatchQueue.main.async {
            if !indexPaths.isEmpty {
                self.tableView.performBatchUpdates({
                    self.tableView.deleteItems(at: indexPaths)
                }, completion: { (_) in
                    self.flowLayout.reset(modal: self.presentingViewController != nil)
                    self.tableView.reloadData()
                })
            }
        }
    }
    
    func hideReadPostsPermanently() {
        var indexPaths: [IndexPath] = []
        var toRemove: [RSubmission] = []
        
        var index = 0
        var count = 0
        for submission in links {
            if History.getSeen(s: submission) {
                indexPaths.append(IndexPath(row: count, section: 0))
                toRemove.append(submission)
                links.remove(at: index)
            } else {
                index += 1
            }
            count += 1
        }
        
        //todo save realm
        DispatchQueue.main.async {
            if !indexPaths.isEmpty {
                self.flowLayout.reset(modal: self.presentingViewController != nil)
                self.tableView.performBatchUpdates({
                    self.tableView.deleteItems(at: indexPaths)
                }, completion: { (_) in
                    self.flowLayout.reset(modal: self.presentingViewController != nil)
                    self.tableView.reloadData()
                })
            }
        }
        
        if let session = (UIApplication.shared.delegate as? AppDelegate)?.session {
            if !indexPaths.isEmpty {
                var hideString = ""
                for item in toRemove {
                    hideString.append(item.getId() + ",")
                }
                hideString = hideString.substring(0, length: hideString.length - 1)
                do {
                    try session.setHide(true, name: hideString) { (result) in
                        print(result)
                    }
                } catch {
                }
            }
        }
    }

    func resetColors() {
        if single {
            navigationController?.navigationBar.barTintColor = ColorUtil.getColorForSub(sub: sub, true)
        }
        setupFab(UIScreen.main.bounds.size)
        if parentController != nil {
            parentController?.colorChanged(ColorUtil.getColorForSub(sub: sub))
        }
    }

    func reloadDataReset() {
        self.flowLayout.reset(modal: self.presentingViewController != nil)
        tableView.reloadData()
        tableView.layoutIfNeeded()
        setupFab(UIScreen.main.bounds.size)
    }
    
    var oldPosition: CGPoint = CGPoint.zero

    @objc func search() {
        let alert = DragDownAlertMenu(title: "Search", subtitle: sub, icon: nil, full: true)
        let searchAction = {
            if !AccountController.isLoggedIn {
                let alert = UIAlertController(title: "Log in to search!", message: "You must be logged into Reddit to search", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Close", style: .default, handler: nil))
                VCPresenter.presentAlert(alert, parentVC: self)
            } else {
                let search = SearchViewController.init(subreddit: self.sub, searchFor: alert.getText() ?? "")
                VCPresenter.showVC(viewController: search, popupIfPossible: true, parentNavigationController: self.navigationController, parentViewController: self)
            }
        }
        
        let searchAllAction = {
            if !AccountController.isLoggedIn {
                let alert = UIAlertController(title: "Log in to search!", message: "You must be logged into Reddit to search", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Close", style: .default, handler: nil))
                VCPresenter.presentAlert(alert, parentVC: self)
            } else {
                let search = SearchViewController.init(subreddit: "all", searchFor: alert.getText() ?? "")
                VCPresenter.showVC(viewController: search, popupIfPossible: true, parentNavigationController: self.navigationController, parentViewController: self)
            }
        }

        if sub != "all" && sub != "frontpage" && sub != "popular" && sub != "random" && sub != "randnsfw" && sub != "friends" && !sub.startsWith("/m/") {
            alert.addTextInput(title: "Search in \(sub)", icon: nil, enabled: false, action: searchAction, inputPlaceholder: "What are you looking for?", inputIcon: UIImage(named: "search")!, textRequired: true, exitOnAction: true)
            alert.addAction(title: "Search all of Reddit", icon: nil, enabled: true, action: searchAllAction)
        } else {
            alert.addTextInput(title: "Search all of Reddit", icon: nil, enabled: false, action: searchAllAction, inputPlaceholder: "What are you looking for?", inputIcon: UIImage(named: "search")!, textRequired: true, exitOnAction: true)
        }
        
        alert.show(self)
    }
    
    @objc func doDisplaySidebar() {
        Sidebar.init(parent: self, subname: self.sub).displaySidebar()
    }

    func filterContent() {
        let alert = AlertController(title: "Content to hide on", message: "r/\(sub)", preferredStyle: .alert)

        let settings = Filter(subreddit: sub, parent: self)
        
        alert.addChild(settings)
        let filterView = settings.view!
        settings.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        alert.setupTheme()
        
        alert.attributedTitle = NSAttributedString(string: "Content to hide on", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 17), NSAttributedString.Key.foregroundColor: ColorUtil.theme.fontColor])
        alert.attributedMessage = NSAttributedString(string: "r/\(sub)", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: ColorUtil.theme.fontColor])
        
        alert.contentView.addSubview(filterView)
        settings.didMove(toParent: alert)

        filterView.verticalAnchors == alert.contentView.verticalAnchors
        filterView.horizontalAnchors == alert.contentView.horizontalAnchors + 8
        filterView.heightAnchor == CGFloat(50 * settings.tableView(settings.tableView, numberOfRowsInSection: 0))
        
        alert.addCancelButton()
        
        alert.addBlurView()

        alert.addCancelButton()
        present(alert, animated: true, completion: nil)
    }

    func galleryMode() {
        if !VCPresenter.proDialogShown(feature: true, self) {
            let controller = GalleryTableViewController()
            var gLinks: [RSubmission] = []
            for l in links {
                if l.banner {
                    gLinks.append(l)
                }
            }
            controller.setLinks(links: gLinks)
            controller.modalPresentationStyle = .overFullScreen
            present(controller, animated: true, completion: nil)
        }
    }

    func shadowboxMode() {
        if !VCPresenter.proDialogShown(feature: true, self) && !links.isEmpty && !self.loading && self.loaded {
            let visibleRect = CGRect(origin: tableView.contentOffset, size: tableView.bounds.size)
            let visiblePoint = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
            let visibleIndexPath = tableView.indexPathForItem(at: visiblePoint)

            let controller = ShadowboxViewController.init(submissions: links, subreddit: sub, index: visibleIndexPath?.row ?? 0, paginator: paginator, sort: sort, time: time)
            controller.modalPresentationStyle = .overFullScreen
            present(controller, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func loadMore() {
        if !showing {
            showLoader()
        }
        load(reset: false)
    }

    func showLoader() {
        showing = true
        //todo maybe?
    }

    @objc func showSortMenu(_ selector: UIView?) {
        let actionSheetController = DragDownAlertMenu(title: "Sorting", subtitle: "", icon: nil, themeColor: ColorUtil.accentColorForSub(sub: sub), full: true)

        let selected = UIImage.init(named: "selected")!.getCopy(withSize: .square(size: 20), withColor: .blue)

        for link in LinkSortType.cases {
            actionSheetController.addAction(title: link.description, icon: sort == link ? selected : nil) {
                self.showTimeMenu(s: link, selector: selector)
            }
        }

        actionSheetController.show(self)
    }

    func showTimeMenu(s: LinkSortType, selector: UIView?) {
        if s == .hot || s == .new || s == .rising || s == .best {
            sort = s
            refresh()
            return
        } else {
            let actionSheetController = DragDownAlertMenu(title: "Select a time period", subtitle: "", icon: nil, themeColor: ColorUtil.accentColorForSub(sub: sub), full: true)

            for t in TimeFilterWithin.cases {
                actionSheetController.addAction(title: t.param, icon: nil) {
                    self.sort = s
                    self.time = t
                    self.refresh()
                }
            }
            
            actionSheetController.show(self)
        }
    }

    @objc func refresh(_ indicator: Bool = true) {
        if indicator {
            self.tableView.setContentOffset(CGPoint(x: 0, y: self.tableView.contentOffset.y - (self.refreshControl!.frame.size.height)), animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: {
                self.refreshControl?.beginRefreshing()
            })
        }
        
        links = []
        self.flowLayout.reset(modal: self.presentingViewController != nil)
        flowLayout.invalidateLayout()
        UIView.transition(with: self.tableView, duration: 0.10, options: .transitionCrossDissolve, animations: {
            self.tableView.reloadData()
        }, completion: nil)
        load(reset: true)
    }

    func deleteSelf(_ cell: LinkCellView) {
        do {
            try session?.deleteCommentOrLink(cell.link!.getId(), completion: { (_) in
                DispatchQueue.main.async {
                    if self.navigationController!.modalPresentationStyle == .formSheet {
                        self.navigationController!.dismiss(animated: true)
                    } else {
                        self.navigationController!.popViewController(animated: true)
                    }
                }
            })
        } catch {

        }
    }
    
    var page = 0
    var reset = false
    var tries = 0

    func load(reset: Bool) {
        self.reset = reset
        PagingCommentViewController.savedComment = nil
        LinkCellView.checkedWifi = false
        if sub.lowercased() == "randnsfw" && !SettingValues.nsfwEnabled {
            DispatchQueue.main.async {
                let alert = UIAlertController.init(title: "r/\(self.sub) is NSFW", message: "You must log into Reddit and enable NSFW content at Reddit.com to view this subreddit", preferredStyle: .alert)
                alert.addAction(UIAlertAction.init(title: "Close", style: .default, handler: { (_) in
                    self.navigationController?.popViewController(animated: true)
                    self.dismiss(animated: true, completion: nil)
                }))
                self.present(alert, animated: true, completion: nil)
            }
            self.refreshControl.endRefreshing()
            return
        } else if sub.lowercased() == "myrandom" && !AccountController.isGold {
            DispatchQueue.main.async {
                let alert = UIAlertController.init(title: "r/\(self.sub) requires gold", message: "See reddit.com/gold/about for more details", preferredStyle: .alert)
                alert.addAction(UIAlertAction.init(title: "Close", style: .default, handler: { (_) in
                    self.navigationController?.popViewController(animated: true)
                    self.dismiss(animated: true, completion: nil)
                }))
                self.present(alert, animated: true, completion: nil)
            }
            self.refreshControl.endRefreshing()
            return
        }
        if !loading {
            if !loaded {
                if indicator == nil {
                    indicator = MDCActivityIndicator.init(frame: CGRect.init(x: CGFloat(0), y: CGFloat(0), width: CGFloat(80), height: CGFloat(80)))
                    indicator?.strokeWidth = 5
                    indicator?.radius = 15
                    indicator?.indicatorMode = .indeterminate
                    indicator?.cycleColors = [ColorUtil.getColorForSub(sub: sub), ColorUtil.accentColorForSub(sub: sub)]
                    self.view.addSubview(indicator!)
                    indicator!.centerAnchors == self.view.centerAnchors
                    indicator?.startAnimating()
                }
            }

            do {
                loading = true
                if reset {
                    paginator = Paginator()
                    self.page = 0
                    self.lastTopItem = 0
                }
                if reset || !loaded {
                    self.startTime = Date()
                }
                var subreddit: SubredditURLPath = Subreddit.init(subreddit: sub)

                if sub.hasPrefix("/m/") {
                    subreddit = Multireddit.init(name: sub.substring(3, length: sub.length - 3), user: AccountController.currentName)
                }
                if sub.contains("/u/") {
                    subreddit = Multireddit.init(name: sub.split("/")[3], user: sub.split("/")[1])
                }
                
                try session?.getList(paginator, subreddit: subreddit, sort: sort, timeFilterWithin: time, completion: { (result) in
                    self.loaded = true
                    self.reset = false
                    switch result {
                    case .failure:
                        print(result.error!)
                        //test if realm exists and show that
                            print("Getting realm data")
                                DispatchQueue.main.async {
                                    do {
                                        let realm = try Realm()
                                        var updated = NSDate()
                                        if let listing = realm.objects(RListing.self).filter({ (item) -> Bool in
                                            return item.subreddit == self.sub
                                        }).first {
                                            self.links = []
                                            for i in listing.links {
                                                self.links.append(i)
                                            }
                                            updated = listing.updated
                                        }
                                        var paths = [IndexPath]()
                                        for i in 0..<self.links.count {
                                            paths.append(IndexPath.init(item: i, section: 0))
                                        }
                                        self.flowLayout.reset(modal: self.presentingViewController != nil)
                                        self.tableView.reloadData()
                                        
                                        self.refreshControl.endRefreshing()
                                        self.indicator?.stopAnimating()
                                        self.indicator?.isHidden = true
                                        self.loading = false
                                        self.loading = false
                                        self.nomore = true
                                        self.offline = true
                                        
                                        var top = CGFloat(0)
                                        if #available(iOS 11, *) {
                                            top += 26
                                            if UIDevice.current.userInterfaceIdiom == .pad || !self.hasTopNotch {
                                                top -= 18
                                            }
                                        }
                                        let navoffset = (-1 * ( (self.navigationController?.navigationBar.frame.size.height ?? 64)))
                                        self.tableView.contentOffset = CGPoint.init(x: 0, y: -18 + navoffset - top)

                                        if self.tries < 1 {
                                            self.tries += 1
                                            self.load(reset: true)
                                        } else {
                                            if self.links.isEmpty {
                                                BannerUtil.makeBanner(text: "No offline content found! You can set up subreddit caching in Settings > Auto Cache", color: ColorUtil.accentColorForSub(sub: self.sub), seconds: 5, context: self)
                                            } else {
                                                self.navigationItem.titleView = self.setTitle(title: self.sub, subtitle: "Content \(DateFormatter().timeSince(from: updated, numericDates: true)) old")
                                            }
                                        }
                                        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: self.tableView)
                                    } catch {
                                        
                                    }

                                }
                    case .success(let listing):
                        self.tries = 0
                        if reset {
                            self.links = []
                            self.page = 0
                        }
                        self.offline = false
                        let before = self.links.count
                        if self.realmListing == nil {
                            self.realmListing = RListing()
                            self.realmListing!.subreddit = self.sub
                            self.realmListing!.updated = NSDate()
                        }
                        if reset && self.realmListing!.links.count > 0 {
                            self.realmListing!.links.removeAll()
                        }

                        let newLinks = listing.children.compactMap({ $0 as? Link })
                        var converted: [RSubmission] = []
                        for link in newLinks {
                            let newRS = RealmDataWrapper.linkToRSubmission(submission: link)
                            converted.append(newRS)
                            CachedTitle.addTitle(s: newRS)
                        }
                        var values = PostFilter.filter(converted, previous: self.links, baseSubreddit: self.sub).map { $0 as! RSubmission }
                        if self.page > 0 && !values.isEmpty && SettingValues.showPages {
                            let pageItem = RSubmission()
                            pageItem.subreddit = DateFormatter().timeSince(from: self.startTime as NSDate, numericDates: true)
                            pageItem.author = "PAGE_SEPARATOR"
                            pageItem.title = "Page \(self.page + 1)\n\(self.links.count + values.count - self.page) posts"
                            values.insert(pageItem, at: 0)
                        }
                        self.page += 1
                        
                        self.links += values
                        self.paginator = listing.paginator
                        self.nomore = !listing.paginator.hasMore() || values.isEmpty
                        do {
                            let realm = try Realm()
                            //todo insert
                            try realm.beginWrite()
                            for submission in self.links {
                                if submission.author != "PAGE_SEPARATOR" {
                                    realm.create(type(of: submission), value: submission, update: true)
                                    if let listing = self.realmListing {
                                        listing.links.append(submission)
                                    }
                                }
                            }
                            
                            realm.create(type(of: self.realmListing!), value: self.realmListing!, update: true)
                            try realm.commitWrite()
                        } catch {

                        }
                        
                        self.preloadImages(values)
                        DispatchQueue.main.async {
                            if self.links.isEmpty {
                                self.flowLayout.reset(modal: self.presentingViewController != nil)
                                self.tableView.reloadData()
                                
                                self.refreshControl.endRefreshing()
                                self.indicator?.stopAnimating()
                                self.indicator?.isHidden = true
                                self.loading = false
                                if MainViewController.first {
                                    MainViewController.first = false
                                    self.parentController?.checkForMail()
                                }
                                if listing.children.isEmpty {
                                    BannerUtil.makeBanner(text: "No posts found!\nMake sure this sub exists and you have permission to view it", color: GMColor.red500Color(), seconds: 5, context: self)
                                } else {
                                    BannerUtil.makeBanner(text: "No posts found!\nCheck your filter settings, or tap here to reload.", color: GMColor.red500Color(), seconds: 5, context: self) {
                                        self.refresh()
                                    }
                                }
                            } else {
                                self.oldPosition = CGPoint.zero
                                var paths = [IndexPath]()
                                for i in before..<self.links.count {
                                    paths.append(IndexPath.init(item: i + self.headerOffset(), section: 0))
                                }

                                if before == 0 {
                                    self.flowLayout.invalidateLayout()
                                    UIView.transition(with: self.tableView, duration: 0.15, options: .transitionCrossDissolve, animations: {
                                        self.tableView.reloadData()
                                    }, completion: nil)
                                    var top = CGFloat(0)
                                    if #available(iOS 11, *) {
                                        top += 26
                                        if UIDevice.current.userInterfaceIdiom == .pad || !self.hasTopNotch {
                                            top -= 18
                                        }
                                    }
                                    let navoffset = (-1 * ( (self.navigationController?.navigationBar.frame.size.height ?? 64)))
                                    let headerHeight = (UIDevice.current.userInterfaceIdiom == .pad ? 0 : self.headerHeight(false))
                                    self.tableView.contentOffset = CGPoint.init(x: 0, y: -18 + navoffset - top + headerHeight)
                                } else {
                                    self.flowLayout.invalidateLayout()
                                    self.tableView.insertItems(at: paths)
                                }
                                self.tableView.isUserInteractionEnabled = true

                                self.indicator?.stopAnimating()
                                self.indicator?.isHidden = true
                                self.refreshControl.endRefreshing()
                                self.loading = false
                                if MainViewController.first {
                                    MainViewController.first = false
                                    self.parentController?.checkForMail()
                                }
                                
                            }
//                            UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: self.tableView)
                        }
                    }
                })
            } catch {
                print(error)
            }

        }
    }
    
    var hasTopNotch: Bool {
        if #available(iOS 11.0, *) {
            return UIApplication.shared.delegate?.window??.safeAreaInsets.top ?? 0 > 20
        }
        return false
    }

    func preloadImages(_ values: [RSubmission]) {
        var urls: [URL] = []
        if !SettingValues.noImages && !(SettingValues.dataSavingDisableWiFi && LinkCellView.checkWiFi()) && SettingValues.dataSavingEnabled {
        for submission in values {
            var thumb = submission.thumbnail
            var big = submission.banner
            var height = submission.height
            if submission.url != nil {
            var type = ContentType.getContentType(baseUrl: submission.url)
            if submission.isSelf {
                type = .SELF
            }

            if thumb && type == .SELF {
                thumb = false
            }

            let fullImage = ContentType.fullImage(t: type)

            if !fullImage && height < 75 {
                big = false
                thumb = true
            } else if big && (SettingValues.postImageMode == .CROPPED_IMAGE) {
                height = 200
            }

            if type == .SELF && SettingValues.hideImageSelftext || SettingValues.hideImageSelftext && !big || type == .SELF {
                big = false
                thumb = false
            }

            if height < 75 {
                thumb = true
                big = false
            }

            let shouldShowLq = SettingValues.dataSavingEnabled && submission.lQ && !(SettingValues.dataSavingDisableWiFi && LinkCellView.checkWiFi())
            if type == ContentType.CType.SELF && SettingValues.hideImageSelftext
                    || SettingValues.noImages && submission.isSelf {
                big = false
                thumb = false
            }

            if big || !submission.thumbnail {
                thumb = false
            }

            if !big && !thumb && submission.type != .SELF && submission.type != .NONE {
                thumb = true
            }

            if thumb && !big {
                if submission.thumbnailUrl == "nsfw" {
                } else if submission.thumbnailUrl == "web" || submission.thumbnailUrl.isEmpty {
                } else {
                    if let url = URL.init(string: submission.thumbnailUrl) {
                        urls.append(url)
                    }
                }
            }

            if big {
                if shouldShowLq {
                    if let url = URL.init(string: submission.lqUrl) {
                        urls.append(url)
                    }

                } else {
                    if let url = URL.init(string: submission.bannerUrl) {
                        urls.append(url)
                    }
                }
            }
            }
        }
        SDWebImagePrefetcher.shared.prefetchURLs(urls)
        }
    }
    
    static func sizeWith(_ submission: RSubmission, _ width: CGFloat, _ isCollection: Bool) -> CGSize {
        let itemWidth = width
        var thumb = submission.thumbnail
        var big = submission.banner
        
        var submissionHeight = CGFloat(submission.height)
        
        var type = ContentType.getContentType(baseUrl: submission.url)
        if submission.isSelf {
            type = .SELF
        }
        
        if SettingValues.postImageMode == .THUMBNAIL {
            big = false
            thumb = true
        }
        
        let fullImage = ContentType.fullImage(t: type)
        
        if !fullImage && submissionHeight < 75 {
            big = false
            thumb = true
        } else if big && (( SettingValues.postImageMode == .CROPPED_IMAGE)) && !(SettingValues.shouldAutoPlay() && (ContentType.displayVideo(t: type) && type != .VIDEO)) {
            submissionHeight = 200
        } else if big {
            let h = getHeightFromAspectRatio(imageHeight: submissionHeight, imageWidth: CGFloat(submission.width), viewWidth: itemWidth - ((SettingValues.postViewMode != .CARD) ? CGFloat(5) : CGFloat(0)))
            if h == 0 {
                submissionHeight = 200
            } else {
                submissionHeight = h
            }
        }
        
        if type == .SELF && SettingValues.hideImageSelftext || SettingValues.hideImageSelftext && !big {
            big = false
            thumb = false
        }
        
        if submissionHeight < 75 {
            thumb = true
            big = false
        }
        
        if type == ContentType.CType.SELF && SettingValues.hideImageSelftext
            || SettingValues.noImages && submission.isSelf {
            big = false
            thumb = false
        }
        
        if big || !submission.thumbnail {
            thumb = false
        }
        
        if (thumb || big) && submission.nsfw && (!SettingValues.nsfwPreviews || SettingValues.hideNSFWCollection && isCollection) {
            big = false
            thumb = true
        }
        
        if SettingValues.noImages && !(SettingValues.dataSavingDisableWiFi && LinkCellView.checkWiFi()) && SettingValues.dataSavingEnabled {
            big = false
            thumb = false
        }
        
        if thumb && type == .SELF {
            thumb = false
        }
        
        if !big && !thumb && submission.type != .SELF && submission.type != .NONE { //If a submission has a link but no images, still show the web thumbnail
            thumb = true
        }
        
        if type == .LINK && SettingValues.linkAlwaysThumbnail {
            thumb = true
            big = false
        }
        
        if (thumb || big) && submission.spoiler {
            thumb = true
            big = false
        }
        
        if big {
            let imageSize = CGSize.init(width: submission.width, height: ((SettingValues.postImageMode == .CROPPED_IMAGE) && !(SettingValues.shouldAutoPlay() && (ContentType.displayVideo(t: type) && type != .VIDEO)) ? 200 : submission.height))
            
            var aspect = imageSize.width / imageSize.height
            if aspect == 0 || aspect > 10000 || aspect.isNaN {
                aspect = 1
            }
            if SettingValues.postImageMode == .CROPPED_IMAGE && !(SettingValues.shouldAutoPlay() && (ContentType.displayVideo(t: type) && type != .VIDEO)) {
                aspect = width / 200
                if aspect == 0 || aspect > 10000 || aspect.isNaN {
                    aspect = 1
                }
                
                submissionHeight = 200
            }
        }
        
        var paddingTop = CGFloat(0)
        var paddingBottom = CGFloat(2)
        var paddingLeft = CGFloat(0)
        var paddingRight = CGFloat(0)
        var innerPadding = CGFloat(0)
        
        if SettingValues.postViewMode == .CARD || SettingValues.postViewMode == .CENTER {
            paddingTop = 5
            paddingBottom = 5
            paddingLeft = 5
            paddingRight = 5
        }
        
        let actionbar = CGFloat(!SettingValues.actionBarMode.isFull() ? 0 : 24)
        
        let thumbheight = (SettingValues.largerThumbnail ? CGFloat(75) : CGFloat(50)) - (SettingValues.postViewMode == .COMPACT ? 15 : 0)
        let textHeight = CGFloat(submission.isSelf ? 5 : 0)
        
        if thumb {
            innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between top and thumbnail
            if SettingValues.actionBarMode.isFull() {
                innerPadding += 18 - (SettingValues.postViewMode == .COMPACT ? 4 : 0) //between label and bottom box
                innerPadding += (SettingValues.postViewMode == .COMPACT ? 4 : 8) //between box and end
            } else {
                innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between thumbnail and bottom
            }
        } else if big {
            if SettingValues.postViewMode == .CENTER {
                innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 16) //between label
                if SettingValues.actionBarMode.isFull() {
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between banner and box
                } else {
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between buttons and bottom
                }
            } else {
                innerPadding += (SettingValues.postViewMode == .COMPACT ? 4 : 8) //between banner and label
                if SettingValues.actionBarMode.isFull() {
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between label and box
                } else {
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between buttons and bottom
                }
            }
            if SettingValues.actionBarMode.isFull() {
                innerPadding += (SettingValues.postViewMode == .COMPACT ? 4 : 8) //between box and end
            }
        } else {
            innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between top and title
            if SettingValues.actionBarMode.isFull() {
                innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between body and box
                innerPadding += (SettingValues.postViewMode == .COMPACT ? 4 : 8) //between box and end
            } else {
                innerPadding += (SettingValues.postViewMode == .COMPACT ? 4 : 8) //between title and bottom
            }
        }
        
        var estimatedUsableWidth = itemWidth - paddingLeft - paddingRight
        if thumb {
            estimatedUsableWidth -= thumbheight //is the same as the width
            estimatedUsableWidth -= (SettingValues.postViewMode == .COMPACT ? 16 : 24) //between edge and thumb
            estimatedUsableWidth -= (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between thumb and label
        } else if SettingValues.actionBarMode.isFull() || SettingValues.actionBarMode == .NONE {
            estimatedUsableWidth -= (SettingValues.postViewMode == .COMPACT ? 16 : 24) //title label padding
        }
        
        if SettingValues.postImageMode == .CROPPED_IMAGE && !(SettingValues.shouldAutoPlay() && (ContentType.displayVideo(t: type) && type != .VIDEO)) {
            submissionHeight = 200
        } else {
            let bannerPadding = (SettingValues.postViewMode != .CARD) ? CGFloat(5) : CGFloat(0)
            submissionHeight = getHeightFromAspectRatio(imageHeight: submissionHeight == 200 ? CGFloat(200) : CGFloat(submission.height), imageWidth: CGFloat(submission.width), viewWidth: width - paddingLeft - paddingRight - (bannerPadding * 2))
        }
        var imageHeight = big && !thumb ? CGFloat(submissionHeight) : CGFloat(0)
        
        if thumb {
            imageHeight = thumbheight
        }
        
        if SettingValues.actionBarMode.isSide() {
            estimatedUsableWidth -= 40
            estimatedUsableWidth -= (SettingValues.postViewMode == .COMPACT ? 8 : 16) //buttons horizontal margins
            if thumb {
                estimatedUsableWidth += (SettingValues.postViewMode == .COMPACT ? 16 : 24) //between edge and thumb no longer exists
                estimatedUsableWidth -= (SettingValues.postViewMode == .COMPACT ? 4 : 8) //buttons buttons and thumb
            }
        }
        
        let size = CGSize(width: estimatedUsableWidth, height: CGFloat.greatestFiniteMagnitude)
        let layout = YYTextLayout(containerSize: size, text: CachedTitle.getTitle(submission: submission, full: false, false))!
        let textSize = layout.textBoundingSize

        let totalHeight = paddingTop + paddingBottom + (thumb ? max(SettingValues.actionBarMode.isSide() ? 72 : 0, ceil(textSize.height), imageHeight) : max(SettingValues.actionBarMode.isSide() ? 72 : 0, ceil(textSize.height)) + imageHeight) + innerPadding + actionbar + textHeight + CGFloat(5)
        return CGSize(width: itemWidth, height: totalHeight)
    }
    
    // TODO: This is mostly replicated by `RSubmission.getLinkView()`. Can we consolidate?
    static func cellType(forSubmission submission: RSubmission, _ isCollection: Bool, cellWidth: CGFloat) -> CurrentType {
        var target: CurrentType = .none

        var thumb = submission.thumbnail
        var big = submission.banner
        let height = CGFloat(submission.height)

        var type = ContentType.getContentType(baseUrl: submission.url)
        if submission.isSelf {
            type = .SELF
        }

        if SettingValues.postImageMode == .THUMBNAIL {
            big = false
            thumb = true
        }

        let fullImage = ContentType.fullImage(t: type)

        var submissionHeight = height
        if !fullImage && submissionHeight < 75 {
            big = false
            thumb = true
        } else if big && SettingValues.postImageMode == .CROPPED_IMAGE {
            submissionHeight = 200
        } else if big {
            let h = getHeightFromAspectRatio(imageHeight: submissionHeight, imageWidth: CGFloat(submission.width), viewWidth: cellWidth)
            if h == 0 {
                submissionHeight = 200
            } else {
                submissionHeight = h
            }
        }

        if type == .SELF && SettingValues.hideImageSelftext || SettingValues.hideImageSelftext && !big {
            big = false
            thumb = false
        }

        if submissionHeight < 75 {
            thumb = true
            big = false
        }

        if type == ContentType.CType.SELF && SettingValues.hideImageSelftext
            || SettingValues.noImages && submission.isSelf {
            big = false
            thumb = false
        }

        if big || !submission.thumbnail {
            thumb = false
        }
        
        if SettingValues.noImages && !(SettingValues.dataSavingDisableWiFi && LinkCellView.checkWiFi()) && SettingValues.dataSavingEnabled {
            big = false
            thumb = false
        }
        
        if thumb && type == .SELF {
            thumb = false
        }

        if !big && !thumb && submission.type != .SELF && submission.type != .NONE { //If a submission has a link but no images, still show the web thumbnail
            thumb = true
        }

        if (thumb || big) && submission.nsfw && (!SettingValues.nsfwPreviews || (SettingValues.hideNSFWCollection && isCollection)) {
            big = false
            thumb = true
        }
        
        if (thumb || big) && submission.spoiler {
            thumb = true
            big = false
        }

        if thumb && !big {
            target = .thumb
        } else if big {
            if SettingValues.autoPlayMode != .NEVER && (ContentType.displayVideo(t: type) && type != .VIDEO) {
                target = .autoplay
            } else {
                target = .banner
            }
        } else {
            target = .text
        }
        
        if big && submissionHeight < 75 {
            target = .thumb
        }

        if type == .LINK && SettingValues.linkAlwaysThumbnail {
            target = .thumb
        }

        return target
    }
    
    var loop: SelectorEventLoop?
    var server: DefaultHTTPServer?
    
    func addToHomescreen() {
        DispatchQueue.global(qos: .background).async { () -> Void in
            self.loop = try! SelectorEventLoop(selector: try! KqueueSelector())
            self.server = DefaultHTTPServer(eventLoop: self.loop!, port: 8080) { (_, startResponse: ((String, [(String, String)]) -> Void), sendBody: ((Data) -> Void)
                ) in
                // Start HTTP response
                startResponse("200 OK", [])
                
                let sub = ColorUtil.getColorForSub(sub: self.sub)
                let lighterSub = sub.add(overlay: UIColor.white.withAlphaComponent(0.4))
                var coloredIcon = UIImage.convertGradientToImage(colors: [lighterSub, sub], frame: CGSize.square(size: 150))
                coloredIcon = coloredIcon.overlayWith(image: UIImage(named: "slideoverlay")!.getCopy(withSize: CGSize.square(size: 150)), posX: 0, posY: 0)
                let imageData: Data = coloredIcon.pngData()! 
                let base64String = imageData.base64EncodedString()

                // send EOF
                let baseHTML = Bundle.main.url(forResource: "html", withExtension: nil)!
                var htmlString = try! String.init(contentsOf: baseHTML, encoding: String.Encoding.utf8)
                htmlString = htmlString.replacingOccurrences(of: "{{subname}}", with: self.sub)
                htmlString = htmlString.replacingOccurrences(of: "{{subcolor}}", with: ColorUtil.getColorForSub(sub: self.sub).toHexString())
                htmlString = htmlString.replacingOccurrences(of: "{{subicon}}", with: base64String)

                print(htmlString)
                let bodyString = htmlString.toBase64()
                sendBody(Data.init(base64Encoded: bodyString!)!)
                sendBody(Data())
            }
            
            // Start HTTP server to listen on the port
            do {
                try self.server?.start()
            } catch let error {
                print(error)
                self.server?.stop()
                do {
                    try self.server?.start()
                } catch {
                    
                }
            }
            
            // Run event loop
            self.loop?.runForever()
            
        }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(URL.init(string: "http://[::1]:8080/foo-bar")!)
        } else {
            // Fallback on earlier versions
            UIApplication.shared.openURL(URL.init(string: "http://[::1]:8080/foo-bar")!)
        }
    }
}

// MARK: - Actions
extension SingleSubredditViewController {

    @objc func spacePressed() {
        UIView.animate(withDuration: 0.2, delay: 0, options: UIView.AnimationOptions.curveEaseOut, animations: {
            self.tableView.contentOffset.y = min(self.tableView.contentOffset.y + 350, self.tableView.contentSize.height - self.tableView.frame.size.height)
        }, completion: nil)
    }
    
    @objc func spacePressedUp() {
        UIView.animate(withDuration: 0.2, delay: 0, options: UIView.AnimationOptions.curveEaseOut, animations: {
            self.tableView.contentOffset.y = max(self.tableView.contentOffset.y - 350, -64)
        }, completion: nil)
    }

    @objc func drefresh(_ sender: AnyObject) {
        refresh()
    }

    @objc func showMoreNone(_ sender: AnyObject) {
        showMore(sender, parentVC: nil)
    }

    @objc func hideAll(_ sender: AnyObject) {
        for submission in links {
            if History.getSeen(s: submission) {
                let index = links.index(of: submission)!
                links.remove(at: index)
            }
        }
        self.flowLayout.reset(modal: self.presentingViewController != nil)
        tableView.reloadData()
    }
    
    @objc func pickTheme(sender: AnyObject?, parent: MainViewController?) {
        parentController = parent
        let alertController = UIAlertController(title: "\n\n\n\n\n\n\n\n", message: nil, preferredStyle: UIAlertController.Style.actionSheet)

        isAccent = false
        let margin: CGFloat = 10.0
        let rect = CGRect(x: margin, y: margin, width: UIScreen.main.traitCollection.userInterfaceIdiom == .pad ? 314 - margin * 4.0: alertController.view.bounds.size.width - margin * 4.0, height: 150)
        let MKColorPicker = ColorPickerView.init(frame: rect)
        MKColorPicker.scrollToPreselectedIndex = true
        MKColorPicker.delegate = self
        MKColorPicker.colors = GMPalette.allColor()
        MKColorPicker.selectionStyle = .check
        MKColorPicker.scrollDirection = .vertical
        MKColorPicker.style = .circle

        let baseColor = ColorUtil.getColorForSub(sub: sub).toHexString()
        var index = 0
        for color in GMPalette.allColor() {
            if color.toHexString() == baseColor {
                break
            }
            index += 1
        }

        MKColorPicker.preselectedIndex = index

        alertController.view.addSubview(MKColorPicker)

        /*todo maybe ?alertController.addAction(image: UIImage.init(named: "accent"), title: "Custom color", color: ColorUtil.accentColorForSub(sub: sub), style: .default, isEnabled: true) { (action) in
         if(!VCPresenter.proDialogShown(feature: false, self)){
         let alert = UIAlertController.init(title: "Choose a color", message: nil, preferredStyle: .actionSheet)
         alert.addColorPicker(color: (self.navigationController?.navigationBar.barTintColor)!, selection: { (c) in
         ColorUtil.setColorForSub(sub: self.sub, color: (self.navigationController?.navigationBar.barTintColor)!)
         self.reloadDataReset()
         self.navigationController?.navigationBar.barTintColor = c
         UIApplication.shared.statusBarView?.backgroundColor = c
         self.sideView.backgroundColor = c
         self.add.backgroundColor = c
         self.sideView.backgroundColor = c
         if (self.parentController != nil) {
         self.parentController?.colorChanged()
         }
         })
         alert.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: { (action) in
         self.pickTheme(sender: sender, parent: parent)
         }))
         self.present(alert, animated: true)
         }

         }*/

        alertController.addAction(image: UIImage(named: "colors"), title: "Accent color", color: ColorUtil.accentColorForSub(sub: sub), style: .default) { _ in
            ColorUtil.setColorForSub(sub: self.sub, color: self.primaryChosen ?? ColorUtil.baseColor)
            self.pickAccent(sender: sender, parent: parent)
            if self.parentController != nil {
                self.parentController?.colorChanged(ColorUtil.getColorForSub(sub: self.sub))
            }
            self.reloadDataReset()
        }

        alertController.addAction(image: nil, title: "Save", color: ColorUtil.accentColorForSub(sub: sub), style: .default) { _ in
            ColorUtil.setColorForSub(sub: self.sub, color: self.primaryChosen ?? ColorUtil.baseColor)
            self.reloadDataReset()
            if self.parentController != nil {
                self.parentController?.colorChanged(ColorUtil.getColorForSub(sub: self.sub))
            }
        }

        alertController.addCancelButton()

        alertController.modalPresentationStyle = .popover
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = sender as! UIButton
            presenter.sourceRect = (sender as! UIButton).bounds
        }

        present(alertController, animated: true, completion: nil)
    }
    
    func pickAccent(sender: AnyObject?, parent: MainViewController?) {
        parentController = parent
        let alertController = UIAlertController(title: "\n\n\n\n\n\n\n\n", message: nil, preferredStyle: UIAlertController.Style.actionSheet)

        isAccent = true
        let margin: CGFloat = 10.0
        let rect = CGRect(x: margin, y: margin, width: UIScreen.main.traitCollection.userInterfaceIdiom == .pad ? 314 - margin * 4.0: alertController.view.bounds.size.width - margin * 4.0, height: 150)
        let MKColorPicker = ColorPickerView.init(frame: rect)
        MKColorPicker.scrollToPreselectedIndex = true
        MKColorPicker.delegate = self
        MKColorPicker.colors = GMPalette.allColorAccent()
        MKColorPicker.selectionStyle = .check
        MKColorPicker.scrollDirection = .vertical
        MKColorPicker.style = .circle

        let baseColor = ColorUtil.accentColorForSub(sub: sub).toHexString()
        var index = 0
        for color in GMPalette.allColorAccent() {
            if color.toHexString() == baseColor {
                break
            }
            index += 1
        }

        MKColorPicker.preselectedIndex = index

        alertController.view.addSubview(MKColorPicker)

        alertController.addAction(image: UIImage(named: "palette"), title: "Primary color", color: ColorUtil.accentColorForSub(sub: sub), style: .default) { _ in
            ColorUtil.setAccentColorForSub(sub: self.sub, color: self.accentChosen ?? ColorUtil.accentColorForSub(sub: self.sub))
            self.pickTheme(sender: sender, parent: parent)
            self.reloadDataReset()
        }

        alertController.addAction(image: nil, title: "Save", color: ColorUtil.accentColorForSub(sub: sub), style: .default) { _ in
            ColorUtil.setAccentColorForSub(sub: self.sub, color: self.accentChosen!)
            self.reloadDataReset()
            if self.parentController != nil {
                self.parentController?.colorChanged(ColorUtil.getColorForSub(sub: self.sub))
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_: UIAlertAction!) in
            self.resetColors()
        })

        alertController.addAction(cancelAction)

        alertController.modalPresentationStyle = .popover
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = sender as! UIButton
            presenter.sourceRect = (sender as! UIButton).bounds
        }

        present(alertController, animated: true, completion: nil)
    }

    @objc func newPost(_ sender: AnyObject) {
        PostActions.showPostMenu(self, sub: self.sub)
    }

    @objc func showMore(_ sender: AnyObject, parentVC: MainViewController? = nil) {

        let alertController = DragDownAlertMenu(title: "Subreddit options", subtitle: sub, icon: nil)
        
        let special = !(sub != "all" && sub != "frontpage" && sub != "popular" && sub != "random" && sub != "randnsfw" && sub != "friends" && !sub.startsWith("/m/"))
        
        alertController.addAction(title: "Search", icon: UIImage(named: "search")!.menuIcon()) {
            self.search()
        }

        if single && !special {
            alertController.addAction(title: Subscriptions.isSubscriber(self.sub) ? "Un-subscribe" : "Subscribe", icon: UIImage(named: Subscriptions.isSubscriber(self.sub) ? "subbed" : "addcircle")!.menuIcon()) {
                self.subscribeSingle(sender)
            }
        }

        alertController.addAction(title: "Sort (currently \(sort.path))", icon:  UIImage(named: "filter")!.menuIcon()) {
            self.showSortMenu(self.more)
        }

        if sub.contains("/m/") {
            alertController.addAction(title: "Manage multireddit", icon: UIImage(named: "info")!.menuIcon()) {
                self.displayMultiredditSidebar()
            }
        } else if !special {
            alertController.addAction(title: "Show sidebar", icon: UIImage(named: "info")!.menuIcon()) {
                self.doDisplaySidebar()
            }
        }
        
        alertController.addAction(title: "Cache for offline viewing", icon: UIImage(named: "save-1")!.menuIcon()) {
            _ = AutoCache.init(baseController: self, subs: [self.sub])
        }

        alertController.addAction(title: "Shadowbox", icon:  UIImage(named: "shadowbox")!.menuIcon()) {
            self.shadowboxMode()
        }

        alertController.addAction(title: "Hide read posts", icon: UIImage(named: "hide")!.menuIcon()) {
            self.hideReadPosts()
        }

        alertController.addAction(title: "Refresh posts", icon: UIImage(named: "sync")!.menuIcon()) {
            self.refresh()
        }

        alertController.addAction(title: "Gallery view", icon: UIImage(named: "image")!.menuIcon()) {
            self.galleryMode()
        }

        alertController.addAction(title: "Custom theme for \(sub)", icon: UIImage(named: "colors")!.menuIcon()) {
            if parentVC != nil {
                let p = (parentVC!)
                self.pickTheme(sender: sender, parent: p)
            } else {
                self.pickTheme(sender: sender, parent: nil)
            }
        }

        if !special {
            alertController.addAction(title: "Submit new post", icon: UIImage(named: "edit")!.menuIcon()) {
                self.newPost(sender)
            }
        }

        alertController.addAction(title: "Filter content from \(sub)", icon: UIImage(named: "filter")!.menuIcon()) {
            if !self.links.isEmpty || self.loaded {
                self.filterContent()
            }
        }

        alertController.addAction(title: "Add homescreen shortcut", icon: UIImage(named: "add_homescreen")!.menuIcon()) {
            self.addToHomescreen()
        }

        alertController.show(self)
    }

}

// MARK: - Collection View Delegate
extension SingleSubredditViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        if cell is AutoplayBannerLinkCellView && (cell as! AutoplayBannerLinkCellView).videoView != nil {
            (cell as! AutoplayBannerLinkCellView).endVideos()
        }
    }
}

extension SingleSubredditViewController: UIScrollViewDelegate {
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        if scrollView.contentOffset.y > oldPosition.y {
            oldPosition = scrollView.contentOffset
            return true
        } else {
            tableView.setContentOffset(oldPosition, animated: true)
            oldPosition = CGPoint.zero
        }
        return false
    }
    
    func markReadScroll() {
        if SettingValues.markReadOnScroll {
            let top = tableView.indexPathsForVisibleItems
            print(top)
            print(lastTopItem)
            if !top.isEmpty {
                let topItem = top[0].row - 1
                if topItem > lastTopItem && topItem < links.count {
                    for item in lastTopItem..<topItem {
                        History.addSeen(s: links[item], skipDuplicates: true)
                    }
                    lastTopItem = topItem
                }
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        markReadScroll()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        markReadScroll()
    }
}

// MARK: - Collection View Data Source
extension SingleSubredditViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (loaded && (!loading || self.links.count > 0) ? headerOffset() : 0) + links.count + (loaded && !reset ? 1 : 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var row = indexPath.row
        if row == 0 && hasHeader {
            let cell = tableView.dequeueReusableCell(withReuseIdentifier: "header", for: indexPath) as! LinksHeaderCellView
            cell.setLinks(links: self.subLinks, sub: self.sub, delegate: self)
            return cell
        }
        if hasHeader {
            row -= 1
        }
        if row >= self.links.count {
            let cell = tableView.dequeueReusableCell(withReuseIdentifier: "loading", for: indexPath) as! LoadingCell
            cell.loader.color = ColorUtil.theme.fontColor
            cell.loader.startAnimating()
            if !loading && !nomore {
                self.loadMore()
            }
            return cell
        }

        let submission = self.links[row]

        if submission.author == "PAGE_SEPARATOR" {
            let cell = tableView.dequeueReusableCell(withReuseIdentifier: "page", for: indexPath) as! PageCell
            
            let textParts = submission.title.components(separatedBy: "\n")
            
            let finalText: NSMutableAttributedString!
            if textParts.count > 1 {
                let firstPart = NSMutableAttributedString.init(string: textParts[0], attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): ColorUtil.theme.fontColor, convertFromNSAttributedStringKey(NSAttributedString.Key.font): UIFont.boldSystemFont(ofSize: 16)]))
                let secondPart = NSMutableAttributedString.init(string: "\n" + textParts[1], attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): ColorUtil.theme.fontColor, convertFromNSAttributedStringKey(NSAttributedString.Key.font): UIFont.systemFont(ofSize: 13)]))
                firstPart.append(secondPart)
                finalText = firstPart
            } else {
                finalText = NSMutableAttributedString.init(string: submission.title, attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): ColorUtil.theme.fontColor, convertFromNSAttributedStringKey(NSAttributedString.Key.font): UIFont.boldSystemFont(ofSize: 14)]))
            }

            cell.time.font = UIFont.systemFont(ofSize: 12)
            cell.time.textColor = ColorUtil.theme.fontColor
            cell.time.alpha = 0.7
            cell.time.text = submission.subreddit
            
            cell.title.attributedText = finalText
            return cell
        }

        var cell: LinkCellView!
        
        if lastVersion != SingleSubredditViewController.cellVersion {
            self.tableView.register(BannerLinkCellView.classForCoder(), forCellWithReuseIdentifier: "banner\(SingleSubredditViewController.cellVersion)")
            self.tableView.register(AutoplayBannerLinkCellView.classForCoder(), forCellWithReuseIdentifier: "autoplay\(SingleSubredditViewController.cellVersion)")
            self.tableView.register(ThumbnailLinkCellView.classForCoder(), forCellWithReuseIdentifier: "thumb\(SingleSubredditViewController.cellVersion)")
            self.tableView.register(TextLinkCellView.classForCoder(), forCellWithReuseIdentifier: "text\(SingleSubredditViewController.cellVersion)")
        }
        
        var numberOfColumns = CGFloat.zero
        var portraitCount = CGFloat(SettingValues.multiColumnCount / 2)
        if portraitCount == 0 {
            portraitCount = 1
        }
        
        let pad = UIScreen.main.traitCollection.userInterfaceIdiom == .pad
        if portraitCount == 1 && pad {
            portraitCount = 2
        }
        
        if SettingValues.appMode == .MULTI_COLUMN {
            if UIApplication.shared.statusBarOrientation.isPortrait {
                if UIScreen.main.traitCollection.userInterfaceIdiom != .pad {
                    numberOfColumns = 1
                } else {
                    numberOfColumns = portraitCount
                }
            } else {
                numberOfColumns = CGFloat(SettingValues.multiColumnCount)
            }
        } else {
            numberOfColumns = 1
        }
        
        if pad && UIApplication.shared.keyWindow?.frame != UIScreen.main.bounds {
            numberOfColumns = 1
        }
        var tableWidth = self.tableView.frame.size.width
        switch SingleSubredditViewController.cellType(forSubmission: submission, Subscriptions.isCollection(sub), cellWidth: (tableWidth == 0 ? UIScreen.main.bounds.size.width : tableWidth) / numberOfColumns ) {
        case .thumb:
            cell = tableView.dequeueReusableCell(withReuseIdentifier: "thumb\(SingleSubredditViewController.cellVersion)", for: indexPath) as! ThumbnailLinkCellView
        case .autoplay:
            cell = tableView.dequeueReusableCell(withReuseIdentifier: "autoplay\(SingleSubredditViewController.cellVersion)", for: indexPath) as! AutoplayBannerLinkCellView
        case .banner:
            cell = tableView.dequeueReusableCell(withReuseIdentifier: "banner\(SingleSubredditViewController.cellVersion)", for: indexPath) as! BannerLinkCellView
        default:
            cell = tableView.dequeueReusableCell(withReuseIdentifier: "text\(SingleSubredditViewController.cellVersion)", for: indexPath) as! TextLinkCellView
        }

        cell.preservesSuperviewLayoutMargins = false
        cell.del = self
        cell.layer.shouldRasterize = true
        cell.layer.rasterizationScale = UIScreen.main.scale
        
        //cell.panGestureRecognizer?.require(toFail: self.tableView.panGestureRecognizer)
        //ecell.panGestureRecognizer2?.require(toFail: self.tableView.panGestureRecognizer)

        cell.configure(submission: submission, parent: self, nav: self.navigationController, baseSub: self.sub, np: false)

        return cell
    }

}

// MARK: - Collection View Prefetching Data Source
//extension SingleSubredditViewController: UICollectionViewDataSourcePrefetching {
//    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
//        // TODO: Implement
//    }
//}

// MARK: - Link Cell View Delegate
extension SingleSubredditViewController: LinkCellViewDelegate {

    func openComments(id: String, subreddit: String?) {
        if let nav = ((self.splitViewController?.viewControllers.count ?? 0 > 1) ? self.splitViewController?.viewControllers[1] : nil) as? UINavigationController, let detail = nav.viewControllers[0] as? PagingCommentViewController {
            if detail.submissions[0].getId() == id {
                return
            }
        }
        var index = 0
        for s in links {
            if s.getId() == id {
                break
            }
            index += 1
        }
        var newLinks: [RSubmission] = []
        for i in index ..< links.count {
            newLinks.append(links[i])
        }
        let comment = PagingCommentViewController.init(submissions: newLinks, offline: self.offline, reloadCallback: { [weak self] in
            if let strongSelf = self {
                strongSelf.tableView.reloadData()
            }
            return true
        })
        VCPresenter.showVC(viewController: comment, popupIfPossible: true, parentNavigationController: self.navigationController, parentViewController: self)
    }
}

// MARK: - Color Picker View Delegate
extension SingleSubredditViewController: ColorPickerViewDelegate {
    public func colorPickerView(_ colorPickerView: ColorPickerView, didSelectItemAt indexPath: IndexPath) {
        if isAccent {
            accentChosen = colorPickerView.colors[indexPath.row]
            self.fab?.backgroundColor = accentChosen
        } else {
            let c = colorPickerView.colors[indexPath.row]
            primaryChosen = c
            self.navigationController?.navigationBar.barTintColor = SettingValues.reduceColor ? ColorUtil.theme.backgroundColor : c
            sideView.backgroundColor = c
            sideView.backgroundColor = c
            inHeadView?.backgroundColor = SettingValues.reduceColor ? ColorUtil.theme.backgroundColor : c
            if SettingValues.fullyHideNavbar {
                inHeadView?.backgroundColor = .clear
            }
            if parentController != nil {
                parentController?.colorChanged(c)
            }
        }
    }
}

// MARK: - Wrapping Flow Layout Delegate
extension SingleSubredditViewController: WrappingFlowLayoutDelegate {
    func headerOffset() -> Int {
        return hasHeader ? 1 : 0
    }
    
    func headerHeight(_ estimate: Bool = true) -> CGFloat {
        if !estimate && SettingValues.alwaysShowHeader {
            return CGFloat(0)
        }
        return CGFloat(hasHeader ? (headerImage != nil ? 180 : 38) : 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, width: CGFloat, indexPath: IndexPath) -> CGSize {
        var row = indexPath.row
        if row == 0 && hasHeader {
            return CGSize(width: width, height: headerHeight())
        }
        row -= self.headerOffset()
        if row < links.count {
            let submission = links[row]
            if submission.author == "PAGE_SEPARATOR" {
                return CGSize(width: width, height: 80)
            }
            return SingleSubredditViewController.sizeWith(submission, width, Subscriptions.isCollection(sub))
        }
        return CGSize(width: width, height: 80)
    }
}

// MARK: - Submission More Delegate
extension SingleSubredditViewController: SubmissionMoreDelegate {
    func hide(index: Int) {
        links.remove(at: index)
        self.flowLayout.reset(modal: self.presentingViewController != nil)
        tableView.reloadData()
    }

    func subscribe(link: RSubmission) {
        let sub = link.subreddit
        let alrController = UIAlertController.init(title: "Follow r/\(sub)", message: nil, preferredStyle: .alert)
        if AccountController.isLoggedIn {
            let somethingAction = UIAlertAction(title: "Subscribe", style: UIAlertAction.Style.default, handler: { (_: UIAlertAction!) in
                Subscriptions.subscribe(sub, true, session: self.session!)
                self.subChanged = true
                BannerUtil.makeBanner(text: "Subscribed to r/\(sub)", color: ColorUtil.accentColorForSub(sub: sub), seconds: 3, context: self, top: true)
            })
            alrController.addAction(somethingAction)
        }
        
        let somethingAction = UIAlertAction(title: "Casually subscribe", style: UIAlertAction.Style.default, handler: { (_: UIAlertAction!) in
            Subscriptions.subscribe(sub, false, session: self.session!)
            self.subChanged = true
            BannerUtil.makeBanner(text: "r/\(sub) added to your subreddit list", color: ColorUtil.accentColorForSub(sub: sub), seconds: 3, context: self, top: true)
        })
        alrController.addAction(somethingAction)
        
        
        alrController.addCancelButton()
        
        alrController.modalPresentationStyle = .fullScreen
        self.present(alrController, animated: true, completion: {})
    }

    func reply(_ cell: LinkCellView) {

    }

    func save(_ cell: LinkCellView) {
        do {
            try session?.setSave(!ActionStates.isSaved(s: cell.link!), name: (cell.link?.getId())!, completion: { (_) in

            })
            ActionStates.setSaved(s: cell.link!, saved: !ActionStates.isSaved(s: cell.link!))
            cell.refresh()
        } catch {

        }
    }

    func upvote(_ cell: LinkCellView) {
        do {
            try session?.setVote(ActionStates.getVoteDirection(s: cell.link!) == .up ? .none : .up, name: (cell.link?.getId())!, completion: { (_) in

            })
            ActionStates.setVoteDirection(s: cell.link!, direction: ActionStates.getVoteDirection(s: cell.link!) == .up ? .none : .up)
            History.addSeen(s: cell.link!)
            cell.refresh()
            cell.refreshTitle(force: true)
        } catch  {
            
        }
    }

    func downvote(_ cell: LinkCellView) {
        do {
            try session?.setVote(ActionStates.getVoteDirection(s: cell.link!) == .down ? .none : .down, name: (cell.link?.getId())!, completion: { (_) in

            })
            ActionStates.setVoteDirection(s: cell.link!, direction: ActionStates.getVoteDirection(s: cell.link!) == .down ? .none : .down)
            History.addSeen(s: cell.link!)
            cell.refresh()
            cell.refreshTitle(force: true)
        } catch {

        }
    }

    func hide(_ cell: LinkCellView) {
        do {
            try session?.setHide(true, name: cell.link!.getId(), completion: { (_) in })
            let id = cell.link!.getId()
            var location = 0
            var item = links[0]
            for submission in links {
                if submission.getId() == id {
                    item = links[location]
                    links.remove(at: location)
                    break
                }
                location += 1
            }

            self.tableView.isUserInteractionEnabled = false

            if !loading {
                tableView.performBatchUpdates({
                    self.tableView.deleteItems(at: [IndexPath.init(item: location, section: 0)])
                }, completion: { (_) in
                    self.tableView.isUserInteractionEnabled = true
                    self.flowLayout.reset(modal: self.presentingViewController != nil)
                    self.tableView.reloadData()
                })
            } else {
                self.flowLayout.reset(modal: self.presentingViewController != nil)
                tableView.reloadData()
            }
            BannerUtil.makeBanner(text: "Hidden forever!\nTap to undo", color: GMColor.red500Color(), seconds: 4, context: self, top: false, callback: {
                self.links.insert(item, at: location)
                self.tableView.insertItems(at: [IndexPath.init(item: location + self.headerOffset(), section: 0)])
                self.flowLayout.reset(modal: self.presentingViewController != nil)
                self.tableView.reloadData()
                do {
                    try self.session?.setHide(false, name: cell.link!.getId(), completion: { (_) in })
                } catch {
                }
            })
        } catch {

        }
    }

    func more(_ cell: LinkCellView) {
        PostActions.showMoreMenu(cell: cell, parent: self, nav: self.navigationController!, mutableList: true, delegate: self, index: tableView.indexPath(for: cell)?.row ?? 0)
    }

    func readLater(_ cell: LinkCellView) {
        guard let link = cell.link else {
            return
        }

        ReadLater.toggleReadLater(link: link)
        if #available(iOS 10.0, *) {
            HapticUtility.hapticActionComplete()
        }
        cell.refresh()
    }

    func mod(_ cell: LinkCellView) {
        PostActions.showModMenu(cell, parent: self)
    }
    
    func applyFilters() {
        self.links = PostFilter.filter(self.links, previous: nil, baseSubreddit: self.sub).map { $0 as! RSubmission }
        self.reloadDataReset()
    }

    func showFilterMenu(_ cell: LinkCellView) {
        let link = cell.link!
        let actionSheetController: UIAlertController = UIAlertController(title: "What would you like to filter?", message: "", preferredStyle: .alert)

        actionSheetController.addCancelButton()
        
        var cancelActionButton = UIAlertAction()
        cancelActionButton = UIAlertAction(title: "Posts by u/\(link.author)", style: .default) { _ -> Void in
            PostFilter.profiles.append(link.author as NSString)
            PostFilter.saveAndUpdate()
            self.links = PostFilter.filter(self.links, previous: nil, baseSubreddit: self.sub).map { $0 as! RSubmission }
            self.reloadDataReset()
        }
        actionSheetController.addAction(cancelActionButton)

        cancelActionButton = UIAlertAction(title: "Posts from r/\(link.subreddit)", style: .default) { _ -> Void in
            PostFilter.subreddits.append(link.subreddit as NSString)
            PostFilter.saveAndUpdate()
            self.links = PostFilter.filter(self.links, previous: nil, baseSubreddit: self.sub).map { $0 as! RSubmission }
            self.reloadDataReset()
        }
        actionSheetController.addAction(cancelActionButton)

        cancelActionButton = UIAlertAction(title: "Posts linking to \(link.domain)", style: .default) { _ -> Void in
            PostFilter.domains.append(link.domain as NSString)
            PostFilter.saveAndUpdate()
            self.links = PostFilter.filter(self.links, previous: nil, baseSubreddit: self.sub).map { $0 as! RSubmission }
            self.reloadDataReset()
        }
        actionSheetController.addAction(cancelActionButton)

        //todo make this work on ipad
        self.present(actionSheetController, animated: true, completion: nil)

    }
}

extension SingleSubredditViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer == panGesture {
            if !SettingValues.submissionGesturesEnabled {
                return false
            }
            
            if SettingValues.submissionActionLeft == .NONE && SettingValues.submissionActionRight == .NONE {
                return false
            }
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.numberOfTouches == 2 {
            return true
        }
        return false
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Limit angle of pan gesture recognizer to avoid interfering with scrolling
        if gestureRecognizer == panGesture {
            if !SettingValues.submissionGesturesEnabled {
                return false
            }
            
            if SettingValues.submissionActionLeft == .NONE && SettingValues.submissionActionRight == .NONE {
                return false
            }
        }
        
        if let recognizer = gestureRecognizer as? UIPanGestureRecognizer, recognizer == panGesture {
            return recognizer.shouldRecognizeForAxis(.horizontal, withAngleToleranceInDegrees: 45)
        }

        return true
    }
    
    @objc func panCell(_ recognizer: UIPanGestureRecognizer) {
        
        if recognizer.view != nil && recognizer.state == .began {
            let velocity = recognizer.velocity(in: recognizer.view!).x
            if (velocity > 0 && SettingValues.submissionActionRight == .NONE) || (velocity < 0 && SettingValues.submissionActionLeft == .NONE) {
                return
            }
        }
        if recognizer.state == .began || translatingCell == nil {
            let point = recognizer.location(in: self.tableView)
            let indexpath = self.tableView.indexPathForItem(at: point)
            if indexpath == nil {
                return
            }
            
            guard let cell = self.tableView.cellForItem(at: indexpath!) as? LinkCellView else {
                return
            }
            translatingCell = cell
        }
        translatingCell?.handlePan(recognizer)
        if recognizer.state == .ended {
            translatingCell = nil
        }
    }
}

public class LoadingCell: UICollectionViewCell {
    var loader = UIActivityIndicatorView()
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        loader.startAnimating()
        
        self.contentView.addSubview(loader)

        loader.topAnchor == self.contentView.topAnchor + 10
        loader.bottomAnchor == self.contentView.bottomAnchor - 10
        loader.centerXAnchor == self.contentView.centerXAnchor
    }
}

public class ReadLaterCell: UICollectionViewCell {
    let title = UILabel()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setArticles(articles: Int) {
        let text = "Read Later "
        let numberText = "(\(articles))"
        let number = NSMutableAttributedString.init(string: numberText, attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): ColorUtil.theme.fontColor, convertFromNSAttributedStringKey(NSAttributedString.Key.font): UIFont.boldSystemFont(ofSize: 15)]))
        let readLater = NSMutableAttributedString.init(string: text, attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): ColorUtil.theme.fontColor, convertFromNSAttributedStringKey(NSAttributedString.Key.font): UIFont.systemFont(ofSize: 15)]))
        let finalText = readLater
        finalText.append(number)

        title.attributedText = finalText
    }
    
    func setupView() {
        title.backgroundColor = ColorUtil.theme.foregroundColor
        title.textAlignment = .center
        
        title.numberOfLines = 0
        
        let titleView: UIView
        if SettingValues.postViewMode == .CARD || SettingValues.postViewMode == .CENTER {
            if !SettingValues.flatMode {
                title.layer.cornerRadius = 15
            }
            titleView = title.withPadding(padding: UIEdgeInsets(top: 8, left: 5, bottom: 0, right: 5))
        } else {
            titleView = title.withPadding(padding: UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0))
        }
        title.clipsToBounds = true
        self.contentView.addSubview(titleView)
        
        titleView.heightAnchor == 60
        titleView.horizontalAnchors == self.contentView.horizontalAnchors
        titleView.topAnchor == self.contentView.topAnchor
    }
}

public class PageCell: UICollectionViewCell {
    var title = UILabel()
    var time = UILabel()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        self.contentView.addSubviews(title, time)
        
        title.heightAnchor == 60
        title.horizontalAnchors == self.contentView.horizontalAnchors
        title.topAnchor == self.contentView.topAnchor + 10
        title.bottomAnchor == self.contentView.bottomAnchor - 10
        title.numberOfLines = 0
        title.lineBreakMode = .byWordWrapping
        title.textAlignment = .center
        title.textColor = ColorUtil.theme.fontColor
        
        time.heightAnchor == 60
        time.leftAnchor == self.contentView.leftAnchor
        time.topAnchor == self.contentView.topAnchor + 10
        time.bottomAnchor == self.contentView.bottomAnchor - 10
        time.numberOfLines = 0
        time.widthAnchor == 70
        time.lineBreakMode = .byWordWrapping
        time.textAlignment = .center
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value) })
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

public class LinksHeaderCellView: UICollectionViewCell {
    var scroll: TouchUIScrollView!
    var links = [SubLinkItem]()
    var sub = ""
    var header = UIView()
    var hasHeader = false
    weak var del: SingleSubredditViewController?
    
    func setLinks(links: [SubLinkItem], sub: String, delegate: SingleSubredditViewController) {
        self.links = links
        self.sub = sub
        self.del = delegate
        self.hasHeader = delegate.headerImage != nil
        setupViews()
    }
    
    func addSubscribe(_ stack: UIStackView, _ scroll: UIScrollView) -> CGFloat {
        let view = UIButton.init(frame: CGRect.init(x: 0, y: 0, width: 100, height: 45)).then {
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 15
            $0.setImage(UIImage(named: "add")?.menuIcon().getCopy(withColor: .white), for: .normal)
            $0.backgroundColor = ColorUtil.accentColorForSub(sub: sub)
            $0.imageView?.contentMode = .center
        }
        view.addTapGestureRecognizer(action: {
            self.del?.subscribeSingle(view)
            stack.removeArrangedSubview(view)
            var oldSize = scroll.contentSize
            oldSize.width -= 38
            stack.widthAnchor == oldSize.width
            scroll.contentSize = oldSize
            view.removeFromSuperview()
        })

        let widthS = CGFloat(30)

        view.heightAnchor == CGFloat(30)
        view.widthAnchor == widthS
        
        stack.addArrangedSubview(view)
        return 30
    }
    func addSubmit(_ stack: UIStackView) -> CGFloat {
        let view = UIButton.init(frame: CGRect.init(x: 0, y: 0, width: 100, height: 45)).then {
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 15
            $0.setImage(UIImage(named: "edit")?.menuIcon().getCopy(withColor: .white), for: .normal)
            $0.backgroundColor = ColorUtil.accentColorForSub(sub: sub)
            $0.imageView?.contentMode = .center
            $0.addTapGestureRecognizer(action: {
                PostActions.showPostMenu(self.del!, sub: self.sub)
            })
        }
        
        let widthS = CGFloat(30)
        
        view.heightAnchor == CGFloat(30)
        view.widthAnchor == widthS
        
        stack.addArrangedSubview(view)
        return 30
    }
    func addSidebar(_ stack: UIStackView) -> CGFloat {
        let view = UIButton.init(frame: CGRect.init(x: 0, y: 0, width: 100, height: 45)).then {
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 15
            $0.setImage(UIImage(named: "info")?.menuIcon().getCopy(withColor: .white), for: .normal)
            $0.backgroundColor = ColorUtil.accentColorForSub(sub: sub)
            $0.imageView?.contentMode = .center
            $0.addTapGestureRecognizer(action: {
                self.del?.doDisplaySidebar()
            })
        }
        
        let widthS = CGFloat(30)

        view.heightAnchor == CGFloat(30)
        view.widthAnchor == widthS
        
        stack.addArrangedSubview(view)
        return 30
    }

    func setupViews() {
        if scroll == nil {
            scroll = TouchUIScrollView()
            
            let buttonBase = UIStackView().then {
                $0.accessibilityIdentifier = "Subreddit links"
                $0.axis = .horizontal
                $0.spacing = 8
            }
            
            var finalWidth = CGFloat(8)
            
            var spacerView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 10))
            buttonBase.addArrangedSubview(spacerView)

            if Subscriptions.subreddits.contains(sub) {
                finalWidth += self.addSubmit(buttonBase) + 8
            } else {
                finalWidth += self.addSubscribe(buttonBase, scroll) + 8
            }
            
            finalWidth += self.addSidebar(buttonBase) + 8

            for link in self.links {
                let view = UIButton.init(frame: CGRect.init(x: 0, y: 0, width: 100, height: 45)).then {
                    $0.layer.cornerRadius = 15
                    $0.clipsToBounds = true
                    $0.setTitle(link.title, for: .normal)
                    $0.setTitleColor(UIColor.white, for: .normal)
                    $0.setTitleColor(.white, for: .selected)
                    $0.titleLabel?.textAlignment = .center
                    $0.titleLabel?.font = UIFont.systemFont(ofSize: 12)
                    $0.backgroundColor = ColorUtil.accentColorForSub(sub: sub)
                    $0.addTapGestureRecognizer(action: {
                        self.del?.doShow(url: link.link!, heroView: nil, heroVC: nil)
                    })
                }
                
                let widthS = view.currentTitle!.size(with: view.titleLabel!.font).width + CGFloat(45)
                
                view.heightAnchor == CGFloat(30)
                view.widthAnchor == widthS
                
                finalWidth += widthS
                finalWidth += 8
                
                buttonBase.addArrangedSubview(view)
            }
            
            spacerView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 10))
            buttonBase.addArrangedSubview(spacerView)
            
            self.contentView.addSubview(scroll)
            self.scroll.isUserInteractionEnabled = true
            self.contentView.isUserInteractionEnabled = true
            buttonBase.isUserInteractionEnabled = true
            
            scroll.heightAnchor == CGFloat(30)
            scroll.horizontalAnchors == self.contentView.horizontalAnchors
            
            scroll.addSubview(buttonBase)
            buttonBase.heightAnchor == CGFloat(30)
            buttonBase.edgeAnchors == scroll.edgeAnchors
            buttonBase.centerYAnchor == scroll.centerYAnchor
            buttonBase.widthAnchor == finalWidth
            scroll.alwaysBounceHorizontal = true
            scroll.showsHorizontalScrollIndicator = false

            if hasHeader && del != nil {
                self.contentView.addSubview(header)

                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFill
                header.addSubview(imageView)
                imageView.clipsToBounds = true
                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    imageView.verticalAnchors == header.verticalAnchors
                    imageView.horizontalAnchors == header.horizontalAnchors + 4
                    imageView.layer.cornerRadius = 15
                } else {
                    imageView.edgeAnchors == header.edgeAnchors
                }
                
                header.heightAnchor == 180
                header.horizontalAnchors == self.contentView.horizontalAnchors
                header.topAnchor == self.contentView.topAnchor + 4
                scroll.topAnchor == self.header.bottomAnchor + 4
                imageView.sd_setImage(with: del!.headerImage!)
                header.heightAnchor == 140
            } else {
                scroll.topAnchor == self.contentView.topAnchor + 4
            }
            scroll.contentSize = CGSize.init(width: finalWidth + 30, height: CGFloat(30))
        }
    }
}

public class SubLinkItem {
    var title = ""
    var link: URL?
    
    init(_ title: String?, link: URL?) {
        self.title = title ?? "LINK"
        self.link = link
    }
}
