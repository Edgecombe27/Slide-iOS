//
//  LinkSettingsPreviewCell.swift
//  Slide for Reddit
//
//  Created by Carlos Crane on 7/19/17.
//  Copyright © 2017 Haptic Apps. All rights reserved.
//


//This is just a recreation of the LinkCellView for use in the Settings > Layout page

import UIKit
import UZTextView
import TTTAttributedLabel
import MaterialComponents
import AudioToolbox
import reddift
import XLActionController

protocol LinkTableViewCellDelegate: class {
    func upvote(_ cell: LinkTableViewCell)
    func downvote(_ cell: LinkTableViewCell)
    func save(_ cell: LinkTableViewCell)
    func more(_ cell: LinkTableViewCell)
    func reply(_ cell: LinkTableViewCell)
    func hide(_ cell: LinkTableViewCell)
}

class LinkTableViewCell: UITableViewCell, UIViewControllerPreviewingDelegate, TTTAttributedLabelDelegate {

    func upvote(sender: UITapGestureRecognizer? = nil) {
        if let delegate = self.del {
            delegate.upvote(self)
        }
    }

    func hide(sender: UITapGestureRecognizer? = nil) {
        if let delegate = self.del {
            delegate.hide(self)
        }
    }


    func reply(sender: UITapGestureRecognizer? = nil) {
        if let delegate = self.del {
            delegate.reply(self)
        }
    }

    func downvote(sender: UITapGestureRecognizer? = nil) {
        if let delegate = self.del {
            delegate.downvote(self)
        }
    }

    func more(sender: UITapGestureRecognizer? = nil) {
        if let delegate = self.del {
            delegate.more(self)
        }
    }

    func save(sender: UITapGestureRecognizer? = nil) {
        if let delegate = self.del {
            delegate.save(self)
        }
    }


    var bannerImage = UIImageView()
    var thumbImage = UIImageView()
    var title = TTTAttributedLabel.init(frame: CGRect.zero)
    var score = UILabel()
    var box = UIStackView()
    var buttons = UIStackView()
    var comments = UILabel()
    var info = UILabel()
    var textView = TTTAttributedLabel.init(frame: CGRect.zero)
    var save = UIImageView()
    var upvote = UIImageView()
    var hide = UIImageView()
    var edit = UIImageView()
    var reply = UIImageView()
    var downvote = UIImageView()
    //var more = UIImageView()
    var commenticon = UIImageView()
    var submissionicon = UIImageView()
    var del: LinkTableViewCellDelegate? = nil
    var taglabel = UILabel()
    var crosspost = UITableViewCell()

    var loadedImage: URL?
    var lq = false

    func attributedLabel(_ label: TTTAttributedLabel!, didLongPressLinkWith url: URL!, at point: CGPoint) {
        if (url) != nil {
            if parentViewController != nil {

                let alertController: BottomSheetActionController = BottomSheetActionController()
                alertController.headerData = url.absoluteString


                let open = OpenInChromeController.init()
                if (open.isChromeInstalled()) {
                    alertController.addAction(Action(ActionData(title: "Open in Chrome", image: UIImage(named: "web")!.menuIcon()), style: .default, handler: { action in
                        open.openInChrome(url, callbackURL: nil, createNewTab: true)
                    }))
                }

                alertController.addAction(Action(ActionData(title: "Open in Safari", image: UIImage(named: "nav")!.menuIcon()), style: .default, handler: { action in
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    } else {
                        UIApplication.shared.openURL(url)
                    }
                }))
                alertController.addAction(Action(ActionData(title: "Copy URL", image: UIImage(named: "save-1")!.menuIcon()), style: .default, handler: { action in
                    UIPasteboard.general.setValue(url, forPasteboardType: "public.url")
                }))
                alertController.addAction(Action(ActionData(title: "Close", image: UIImage(named: "close")!.menuIcon()), style: .default, handler: { action in
                }))

                VCPresenter.presentAlert(alertController, parentVC: parentViewController!)
            }
        }
    }

    func attributedLabel(_ label: TTTAttributedLabel!, didSelectLinkWith url: URL!) {
        print("Clicked \(url.absoluteString)")
        if ((parentViewController) != nil) {
            parentViewController?.doShow(url: url)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {

        /*  let pointForTargetViewmore: CGPoint = more.convert(point, from: self)
          if more.bounds.contains(pointForTargetViewmore) {
              return more
          }*/
        let pointForTargetViewdownvote: CGPoint = downvote.convert(point, from: self)
        if downvote.bounds.contains(pointForTargetViewdownvote) {
            return downvote
        }

        let pointForTargetViewupvote: CGPoint = upvote.convert(point, from: self)
        if upvote.bounds.contains(pointForTargetViewupvote) {
            return upvote
        }
        let pointForTargetViewsave: CGPoint = save.convert(point, from: self)
        if save.bounds.contains(pointForTargetViewsave) {
            return save
        }
        let pointForTargetViewh: CGPoint = hide.convert(point, from: self)
        if hide.bounds.contains(pointForTargetViewh) {
            return hide
        }

        let pointForTargetViewreply: CGPoint = reply.convert(point, from: self)
        if reply.bounds.contains(pointForTargetViewreply) {
            return reply
        }
        let pointForTargetViewedit: CGPoint = edit.convert(point, from: self)
        if edit.bounds.contains(pointForTargetViewedit) {
            return edit
        }


        return super.hitTest(point, with: event)
    }

    var content: CellContent?
    var hasText = false

    func showBody(width: CGFloat) {
        full = true
        let link = self.link!
        let color = ColorUtil.accentColorForSub(sub: ((link).subreddit))
        if (!link.htmlBody.isEmpty) {
            let html = link.htmlBody.trimmed()
            do {
                let attr = html.toAttributedString()!
                let font = FontGenerator.fontOfSize(size: 16, submission: false)
                let attr2 = attr.reconstruct(with: font, color: ColorUtil.fontColor, linkColor: color)
                content = CellContent.init(string: LinkParser.parse(attr2, color), width: (width - 24 - (thumb ? 75 : 0)))
                let activeLinkAttributes = NSMutableDictionary(dictionary: title.activeLinkAttributes)
                activeLinkAttributes[NSForegroundColorAttributeName] = ColorUtil.accentColorForSub(sub: link.subreddit)
                textView.activeLinkAttributes = activeLinkAttributes as NSDictionary as! [AnyHashable: Any]
                textView.linkAttributes = activeLinkAttributes as NSDictionary as! [AnyHashable: Any]

                textView.delegate = self
                textView.setText(content?.attributedString)
                textView.frame.size.height = (content?.textHeight)!
                hasText = true
            } catch {
            }
            parentViewController?.registerForPreviewing(with: self, sourceView: textView)
        }
    }

    var full = false
    var b = UIView()
    var estimatedHeight = CGFloat(0)
    var tagbody = UIView()

    func estimateHeight(_ full: Bool, _ reset: Bool = false) -> CGFloat {
        if (estimatedHeight == 0 || reset) {
            var paddingTop = CGFloat(0)
            var paddingBottom = CGFloat(2)
            var paddingLeft = CGFloat(0)
            var paddingRight = CGFloat(0)
            var innerPadding = CGFloat(0)
            if (SettingValues.postViewMode == .CARD && !full) {
                paddingTop = 5
                paddingBottom = 5
                paddingLeft = 5
                paddingRight = 5
            }

            let actionbar = CGFloat(!full && SettingValues.hideButtonActionbar ? 0 : 24)

            var imageHeight = big && !thumb ? CGFloat(submissionHeight) : CGFloat(0)
            let thumbheight = SettingValues.largerThumbnail ? CGFloat(75) : CGFloat(50)
            let textHeight = (!hasText || !full) ? CGFloat(0) : CGFloat((content?.textHeight)!)

            if (thumb) {
                imageHeight = thumbheight
                innerPadding += 8 //between top and thumbnail
                innerPadding += 18 //between label and bottom box
                innerPadding += 8 //between box and end
            } else if (big) {
                if (SettingValues.centerLeadImage || full) {
                    innerPadding += 16 //between label
                    innerPadding += 12 //between banner and box
                } else {
                    innerPadding += 8 //between banner and label
                    innerPadding += 12 //between label and box
                }

                innerPadding += 8 //between box and end
            } else {
                innerPadding += 8
                innerPadding += 5 //between label and body
                innerPadding += 12 //between body and box
                innerPadding += 8 //between box and end
            }

            var estimatedUsableWidth = aspectWidth - paddingLeft - paddingRight
            if (thumb) {
                estimatedUsableWidth -= thumbheight //is the same as the width
                estimatedUsableWidth -= 12 //between edge and thumb
                estimatedUsableWidth -= 8 //between thumb and label
            } else {
                estimatedUsableWidth -= 24 //12 padding on either side
            }

            let framesetter = CTFramesetterCreateWithAttributedString(title.attributedText)
            let textSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil, CGSize.init(width: estimatedUsableWidth, height: CGFloat.greatestFiniteMagnitude), nil)

            let totalHeight = paddingTop + paddingBottom + (thumb ? max(ceil(textSize.height), imageHeight) : ceil(textSize.height) + imageHeight) + innerPadding + actionbar + textHeight + (full ? CGFloat(10) : CGFloat(0))
            estimatedHeight = totalHeight
        }
        return estimatedHeight
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.thumbImage = UIImageView(frame: CGRect(x: 0, y: 8, width: (SettingValues.largerThumbnail ? 75 : 50), height: (SettingValues.largerThumbnail ? 75 : 50)))
        thumbImage.layer.cornerRadius = 15;
        thumbImage.backgroundColor = UIColor.white
        thumbImage.clipsToBounds = true;
        thumbImage.contentMode = .scaleAspectFill
        thumbImage.elevate(elevation: 2.0)

        self.bannerImage = UIImageView(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: 0))
        bannerImage.contentMode = UIViewContentMode.scaleAspectFill
        bannerImage.layer.cornerRadius = 15;
        bannerImage.clipsToBounds = true
        bannerImage.backgroundColor = UIColor.white

        self.title = TTTAttributedLabel(frame: CGRect(x: 75, y: 8, width: contentView.frame.width, height: CGFloat.greatestFiniteMagnitude));
        title.numberOfLines = 0
        title.lineBreakMode = NSLineBreakMode.byWordWrapping
        title.font = FontGenerator.fontOfSize(size: 18, submission: true)

        self.upvote = UIImageView(frame: CGRect(x: 0, y: 0, width: 34, height: 20))

        self.hide = UIImageView(frame: CGRect(x: 0, y: 0, width: 34, height: 20))
        hide.image = UIImage.init(named: "hide")?.menuIcon()


        self.reply = UIImageView(frame: CGRect(x: 0, y: 0, width: 34, height: 20))
        reply.image = UIImage.init(named: "reply")?.menuIcon()

        self.edit = UIImageView(frame: CGRect(x: 0, y: 0, width: 34, height: 20))
        edit.image = UIImage.init(named: "edit")?.menuIcon()

        self.save = UIImageView(frame: CGRect(x: 0, y: 0, width: 34, height: 20))

        self.downvote = UIImageView(frame: CGRect(x: 0, y: 0, width: 34, height: 20))

        //self.more = UIImageView(frame: CGRect(x: 0, y: 0, width: 30, height: 20))
        //more.image = UIImage.init(named: "ic_more_vert_white")?.withColor(tintColor: ColorUtil.fontColor).imageResize(sizeChange: CGSize.init(width: 17, height: 17))

        self.commenticon = UIImageView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        commenticon.image = UIImage.init(named: "comments")?.menuIcon()

        self.submissionicon = UIImageView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        submissionicon.image = UIImage.init(named: "upvote")?.menuIcon()

        submissionicon.contentMode = .scaleAspectFit
        commenticon.contentMode = .scaleAspectFit


        upvote.contentMode = .center
        downvote.contentMode = .center
        hide.contentMode = .center
        reply.contentMode = .center
        edit.contentMode = .center
        save.contentMode = .center

        self.textView = TTTAttributedLabel(frame: CGRect(x: 75, y: 8, width: contentView.frame.width, height: CGFloat.greatestFiniteMagnitude))
        self.textView.delegate = self
        self.textView.numberOfLines = 0
        self.textView.isUserInteractionEnabled = true
        self.textView.backgroundColor = .clear

        self.score = UILabel(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude));
        score.numberOfLines = 1
        score.font = FontGenerator.fontOfSize(size: 12, submission: true)
        score.textColor = ColorUtil.fontColor


        self.comments = UILabel(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude));
        comments.numberOfLines = 1
        comments.font = FontGenerator.fontOfSize(size: 12, submission: true)
        comments.textColor = ColorUtil.fontColor

        self.taglabel = UILabel(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude));
        taglabel.numberOfLines = 1
        taglabel.font = FontGenerator.boldFontOfSize(size: 12, submission: true)
        taglabel.textColor = UIColor.black

        tagbody = taglabel.withPadding(padding: UIEdgeInsets.init(top: 1, left: 1, bottom: 1, right: 1))
        tagbody.backgroundColor = UIColor.white
        tagbody.clipsToBounds = true
        tagbody.layer.cornerRadius = 4


        self.info = UILabel(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude));
        info.numberOfLines = 2
        info.font = FontGenerator.fontOfSize(size: 12, submission: true)
        info.textColor = .white
        b = info.withPadding(padding: UIEdgeInsets.init(top: 4, left: 10, bottom: 4, right: 10))
        b.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        b.clipsToBounds = true
        b.layer.cornerRadius = 10

        self.box = UIStackView(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude));
        self.buttons = UIStackView(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude));

        bannerImage.translatesAutoresizingMaskIntoConstraints = false
        thumbImage.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false
        score.translatesAutoresizingMaskIntoConstraints = false
        comments.translatesAutoresizingMaskIntoConstraints = false
        box.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        upvote.translatesAutoresizingMaskIntoConstraints = false
        hide.translatesAutoresizingMaskIntoConstraints = false
        downvote.translatesAutoresizingMaskIntoConstraints = false
        //more.translatesAutoresizingMaskIntoConstraints = false
        edit.translatesAutoresizingMaskIntoConstraints = false
        save.translatesAutoresizingMaskIntoConstraints = false
        reply.translatesAutoresizingMaskIntoConstraints = false
        buttons.translatesAutoresizingMaskIntoConstraints = false
        b.translatesAutoresizingMaskIntoConstraints = false
        tagbody.translatesAutoresizingMaskIntoConstraints = false

        commenticon.translatesAutoresizingMaskIntoConstraints = false
        submissionicon.translatesAutoresizingMaskIntoConstraints = false

        if (!addTouch) {
            addTouch(view: save, action: #selector(LinkTableViewCell.save(sender:)))
            addTouch(view: upvote, action: #selector(LinkTableViewCell.upvote(sender:)))
            addTouch(view: reply, action: #selector(LinkTableViewCell.reply(sender:)))
            addTouch(view: downvote, action: #selector(LinkTableViewCell.downvote(sender:)))
            addTouch(view: hide, action: #selector(LinkTableViewCell.hide(sender:)))
            addTouch = true
        }

        self.contentView.addSubview(bannerImage)
        self.contentView.addSubview(thumbImage)
        self.contentView.addSubview(title)
        self.contentView.addSubview(textView)
        self.contentView.addSubview(b)
        self.contentView.addSubview(tagbody)
        box.addSubview(score)
        box.addSubview(comments)
        box.addSubview(commenticon)
        box.addSubview(submissionicon)

        buttons.addSubview(edit)
        buttons.addSubview(reply)
        buttons.addSubview(save)
        buttons.addSubview(hide)
        buttons.addSubview(upvote)
        buttons.addSubview(downvote)
        //buttons.addSubview(more)
        self.contentView.addSubview(box)
        self.contentView.addSubview(buttons)

        buttons.isUserInteractionEnabled = true
        bannerImage.contentMode = UIViewContentMode.scaleAspectFill
        bannerImage.layer.cornerRadius = 15;
        bannerImage.clipsToBounds = true
        bannerImage.backgroundColor = UIColor.white
        thumbImage.layer.cornerRadius = 10;
        thumbImage.backgroundColor = UIColor.white
        thumbImage.clipsToBounds = true;
        thumbImage.contentMode = .scaleAspectFill

    }

    func addTouch(view: UIView, action: Selector) {
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: action)
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    var thumb = true
    var submissionHeight: Int = 0
    var addTouch = false

    override func updateConstraints() {
        super.updateConstraints()
        var topmargin = 0
        var bottommargin = 2
        var leftmargin = 0
        var rightmargin = 0
        var innerpadding = 0
        var radius = 0

        if (SettingValues.postViewMode == .CARD && !full) {
            topmargin = 5
            bottommargin = 5
            leftmargin = 5
            rightmargin = 5
            innerpadding = 5
            radius = 15
        }

        self.contentView.layoutMargins = UIEdgeInsets.init(top: CGFloat(topmargin), left: CGFloat(leftmargin), bottom: CGFloat(bottommargin), right: CGFloat(rightmargin))

        let metrics = ["horizontalMargin": 75, "top": topmargin, "bottom": bottommargin, "separationBetweenLabels": 0, "labelMinHeight": 75, "bannerHeight": submissionHeight, "left": leftmargin, "padding": innerpadding, "ishidden": !full && SettingValues.hideButtonActionbar ? 0 : 24, "ishiddeni": !full && SettingValues.hideButtonActionbar ? 0 : 18] as [String: Int]
        let views = ["label": title, "body": textView, "image": thumbImage, "score": score, "comments": comments, "banner": bannerImage, "scorei": submissionicon, "commenti": commenticon, "box": box] as [String: Any]
        let views2 = ["buttons": buttons, "upvote": upvote, "downvote": downvote, "hide": hide, "reply": reply, "edit": edit, "save": save] as [String: Any]

        box.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-16-[scorei(12)]-2-[score(>=20)]-8-[commenti(12)]-2-[comments(>=20)]",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views))

        box.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[score(ishidden)]-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views))
        box.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[scorei(ishiddeni)]-4-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views))
        box.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[commenti(ishiddeni)]-4-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views))

        self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[buttons(ishidden)]-12-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views2))

        box.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[comments(ishidden)]-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views))

        self.contentView.layer.cornerRadius = CGFloat(radius)
        self.contentView.layer.masksToBounds = true


        let hideString = SettingValues.hideButton ? "[hide(24)]-12-" : ""
        let saveString = SettingValues.saveButton ? "[save(24)]-12-" : ""
        buttons.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:\(hideString)\(saveString)[upvote(24)]-16-[downvote(24)]-8-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views2))

        buttons.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[upvote(ishidden)]-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views2))

        buttons.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[downvote(ishidden)]-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views2))

        buttons.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[save(ishidden)]-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views2))
        buttons.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[hide(ishidden)]-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views2))

        buttons.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[reply(ishidden)]-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views2))
        buttons.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[edit(ishidden)]-|",
                options: NSLayoutFormatOptions(rawValue: 0),
                metrics: metrics,
                views: views2))

    }

    func getHeightFromAspectRatio(imageHeight: Int, imageWidth: Int) -> Int {
        let ratio = Double(imageHeight) / Double(imageWidth)
        let width = Double(contentView.frame.size.width);
        return Int(width * ratio)

    }

    var big = false
    var bigConstraint: NSLayoutConstraint?
    var thumbConstraint: [NSLayoutConstraint] = []

    func refreshLink(_ submission: RSubmission) {
        self.link = submission

        title.setText(CachedTitle.getTitle(submission: submission, full: full, true, false))

        if (!full) {
            let comment = UITapGestureRecognizer(target: self, action: #selector(LinkTableViewCell.openComment(sender:)))
            comment.delegate = self
            self.addGestureRecognizer(comment)
        }

        refresh()


        let more = History.commentsSince(s: submission)

        comments.text = " \(submission.commentCount)" + (more > 0 ? " (+\(more))" : "")

    }

    var link: RSubmission?
    var aspectWidth = CGFloat(0)

    func setLink(submission: RSubmission, parent: MediaViewController, nav: UIViewController?, baseSub: String) {
        loadedImage = nil
        full = parent is CommentViewController
        lq = false
        if (true || full) { //todo logic for this
            self.contentView.backgroundColor = ColorUtil.foregroundColor
            comments.textColor = ColorUtil.fontColor
            title.textColor = ColorUtil.fontColor
        } else {
            self.contentView.backgroundColor = ColorUtil.getColorForSubBackground(sub: submission.subreddit)
            comments.textColor = .white
            title.textColor = .white
        }

        parentViewController = parent
        self.link = submission
        if (navViewController == nil && nav != nil) {
            navViewController = nav
        }

        title.setText(CachedTitle.getTitle(submission: submission, full: full, false
                , false))

        let activeLinkAttributes = NSMutableDictionary(dictionary: title.activeLinkAttributes)
        activeLinkAttributes[NSForegroundColorAttributeName] = ColorUtil.accentColorForSub(sub: submission.subreddit)
        title.activeLinkAttributes = activeLinkAttributes as NSDictionary as! [AnyHashable: Any]
        title.linkAttributes = activeLinkAttributes as NSDictionary as! [AnyHashable: Any]

        reply.isHidden = true

        if (!SettingValues.hideButton) {
            hide.isHidden = true
        } else {
            if (!addTouch) {
                addTouch(view: hide, action: #selector(LinkTableViewCell.hide(sender:)))
            }
            hide.isHidden = false
        }
        if (!SettingValues.saveButton) {
            save.isHidden = true
        } else {
            if (!addTouch) {
                addTouch(view: save, action: #selector(LinkTableViewCell.save(sender:)))
            }
            save.isHidden = false
        }
        if (submission.archived || !AccountController.isLoggedIn) {
            upvote.isHidden = true
            downvote.isHidden = true
            save.isHidden = true
            reply.isHidden = true
            edit.isHidden = true
        } else {
            upvote.isHidden = false
            downvote.isHidden = false
            if (!addTouch) {
                addTouch(view: upvote, action: #selector(LinkTableViewCell.upvote(sender:)))
                addTouch(view: downvote, action: #selector(LinkTableViewCell.downvote(sender:)))
            }

            edit.isHidden = true
        }
        //addTouch(view: more, action: #selector(LinkTableViewCell.more(sender:)))

        full = parent is CommentViewController

        if (!submission.archived && AccountController.isLoggedIn && AccountController.currentName == submission.author && full) {
            edit.isHidden = false
        }

        thumb = submission.thumbnail
        big = submission.banner

        if (bigConstraint != nil) {
            self.contentView.removeConstraint(bigConstraint!)
        }

        submissionHeight = submission.height

        var type = ContentType.getContentType(baseUrl: submission.url!)
        if (submission.isSelf) {
            type = .SELF
        }

        if (SettingValues.bannerHidden && !full) {
            big = false
            thumb = true
        }

        let fullImage = ContentType.fullImage(t: type)

        if (!fullImage && submissionHeight < 50) {
            big = false
            thumb = true
        } else if (big && (SettingValues.bigPicCropped || full)) {
            submissionHeight = 200
        } else if (big) {
            let h = getHeightFromAspectRatio(imageHeight: submissionHeight, imageWidth: submission.width)
            if (h == 0) {
                submissionHeight = 200
            } else {
                submissionHeight = h
            }
        }

        if (SettingValues.hideButtonActionbar && !full) {
            buttons.isHidden = true
            box.isHidden = true
        }

        if (type == .SELF && SettingValues.hideImageSelftext || SettingValues.hideImageSelftext && !big || type == .SELF && full) {
            big = false
            thumb = false
        }

        if (submissionHeight < 50) {
            thumb = true
            big = false
        }

        let shouldShowLq = SettingValues.dataSavingEnabled && submission.lQ && !(SettingValues.dataSavingDisableWiFi && LinkTableViewCell.checkWiFi())
        if (type == ContentType.CType.SELF && SettingValues.hideImageSelftext
                || SettingValues.noImages && submission.isSelf) {
            big = false
            thumb = false
        }

        if (big || !submission.thumbnail) {
            thumb = false
        }

        if (submission.nsfw && (!SettingValues.nsfwPreviews || SettingValues.hideNSFWCollection && (baseSub == "all" || baseSub == "frontpage" || baseSub.contains("/m/") || baseSub.contains("+") || baseSub == "popular"))) {
            big = false
            thumb = true
        }


        if (SettingValues.noImages) {
            big = false
            thumb = false
        }

        if (thumb && type == .SELF) {
            thumb = false
        }

        if (!big && !thumb && submission.type != .SELF && submission.type != .NONE) { //If a submission has a link but no images, still show the web thumbnail
            thumb = true
            addTouch(view: thumbImage, action: #selector(LinkTableViewCell.openLink(sender:)))
            thumbImage.image = UIImage.init(named: "web")
        } else if (thumb && !big) {
            addTouch(view: thumbImage, action: #selector(LinkTableViewCell.openLink(sender:)))
            if (submission.nsfw) {
                thumbImage.image = UIImage.init(named: "nsfw")
            } else if (submission.thumbnailUrl == "web" || submission.thumbnailUrl.isEmpty) {
                thumbImage.image = UIImage.init(named: "web")
            } else {
                thumbImage.sd_setImage(with: URL.init(string: submission.thumbnailUrl), placeholderImage: UIImage.init(named: "web"))
            }
        } else {
            thumbImage.sd_setImage(with: URL.init(string: ""))
            self.thumbImage.frame.size.width = 0
        }


        if (big) {
            bannerImage.alpha = 0
            let imageSize = CGSize.init(width: submission.width, height: (full || SettingValues.bigPicCropped) ? 200 : submission.height);
            var aspect = imageSize.width / imageSize.height
            if (aspect == 0 || aspect > 10000 || aspect.isNaN) {
                aspect = 1
            }
            if (full || SettingValues.bigPicCropped) {
                aspect = (full ? aspectWidth : self.contentView.frame.size.width) / 200
                submissionHeight = 200
                bigConstraint = NSLayoutConstraint(item: bannerImage, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: bannerImage, attribute: NSLayoutAttribute.height, multiplier: aspect, constant: 0.0)
            } else {
                bigConstraint = NSLayoutConstraint(item: bannerImage, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: bannerImage, attribute: NSLayoutAttribute.height, multiplier: aspect, constant: 0.0)
            }
            bannerImage.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(LinkTableViewCell.openLink(sender:)))
            tap.delegate = self
            bannerImage.addGestureRecognizer(tap)

            let tap2 = UITapGestureRecognizer(target: self, action: #selector(LinkTableViewCell.openLink(sender:)))
            tap2.delegate = self

            b.addGestureRecognizer(tap2)
            if (shouldShowLq) {
                lq = true
                loadedImage = URL.init(string: submission.lqUrl)
                bannerImage.sd_setImage(with: URL.init(string: submission.lqUrl), completed: { (image, error, cache, url) in
                    self.bannerImage.contentMode = .scaleAspectFill
                    if (cache == .none) {
                        UIView.animate(withDuration: 0.3, animations: {
                            self.bannerImage.alpha = 1
                        })
                    } else {
                        self.bannerImage.alpha = 1
                    }
                })
            } else {
                loadedImage = URL.init(string: submission.bannerUrl)
                bannerImage.sd_setImage(with: URL.init(string: submission.bannerUrl), completed: { (image, error, cache, url) in
                    self.bannerImage.contentMode = .scaleAspectFill
                    if (cache == .none) {
                        UIView.animate(withDuration: 0.3, animations: {
                            self.bannerImage.alpha = 1
                        })
                    } else {
                        self.bannerImage.alpha = 1
                    }
                })
            }
        } else {
            bannerImage.sd_setImage(with: URL.init(string: ""))
        }

        if (!full) {
            aspectWidth = self.contentView.frame.size.width
        }

        if (!full) {
            let comment = UITapGestureRecognizer(target: self, action: #selector(LinkTableViewCell.openComment(sender:)))
            comment.delegate = self
            self.addGestureRecognizer(comment)
        }

        //title.sizeToFit()

        let mo = History.commentsSince(s: submission)
        comments.text = " \(submission.commentCount)" + (mo > 0 ? "(+\(mo))" : "")

        if (!registered && !full) {
            parent.registerForPreviewing(with: self, sourceView: self.contentView)
            registered = true
        }

        doConstraints()

        refresh()
        if (full) {
            self.setNeedsLayout()
        }

        if (type != .IMAGE && type != .SELF && !thumb) {
            b.isHidden = false
            var text = ""
            switch (type) {
            case .ALBUM:
                text = ("Album")
                break
            case .EXTERNAL:
                text = "External Link"
                break
            case .LINK, .EMBEDDED, .NONE:
                text = "Link"
                break
            case .DEVIANTART:
                text = "Deviantart"
                break
            case .TUMBLR:
                text = "Tumblr"
                break
            case .XKCD:
                text = ("XKCD")
                break
            case .GIF:
                text = ("GIF")
                break
            case .IMGUR:
                text = ("Imgur")
                break
            case .VIDEO:
                text = "YouTube"
                break
            case .STREAMABLE:
                text = "Streamable"
                break
            case .VID_ME:
                text = ("Vid.me")
                break
            case .REDDIT:
                text = ("Reddit content")
                break
            default:
                text = "Link"
                break
            }

            if (SettingValues.smallerTag && !full) {
                b.isHidden = true
                tagbody.isHidden = false
                taglabel.text = " \(text.uppercased()) "
            } else {
                tagbody.isHidden = true
                if (submission.isCrosspost && full) {
                    var colorF = UIColor.white

                    let finalText = NSMutableAttributedString.init(string: "Crosspost - " + submission.domain, attributes: [NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: FontGenerator.boldFontOfSize(size: 14, submission: true)])

                    let endString = NSMutableAttributedString(string: "\nOriginal submission by ", attributes: [NSFontAttributeName: FontGenerator.fontOfSize(size: 12, submission: true), NSForegroundColorAttributeName: colorF])
                    let by = NSMutableAttributedString(string: " in ", attributes: [NSFontAttributeName: FontGenerator.fontOfSize(size: 12, submission: true), NSForegroundColorAttributeName: colorF])

                    let authorString = NSMutableAttributedString(string: "\u{00A0}\(submission.author)\u{00A0}", attributes: [NSFontAttributeName: FontGenerator.fontOfSize(size: 12, submission: true), NSForegroundColorAttributeName: colorF])


                    let userColor = ColorUtil.getColorForUser(name: submission.crosspostAuthor)
                    if (AccountController.currentName == submission.author) {
                        authorString.addAttributes([kTTTBackgroundFillColorAttributeName: UIColor.init(hexString: "#FFB74D"), NSFontAttributeName: FontGenerator.boldFontOfSize(size: 12, submission: false), NSForegroundColorAttributeName: UIColor.white, kTTTBackgroundFillPaddingAttributeName: UIEdgeInsets.init(top: 1, left: 1, bottom: 1, right: 1), kTTTBackgroundCornerRadiusAttributeName: 3], range: NSRange.init(location: 0, length: authorString.length))
                    } else if (userColor != ColorUtil.baseColor) {
                        authorString.addAttributes([kTTTBackgroundFillColorAttributeName: userColor, NSFontAttributeName: FontGenerator.boldFontOfSize(size: 12, submission: false), NSForegroundColorAttributeName: UIColor.white, kTTTBackgroundFillPaddingAttributeName: UIEdgeInsets.init(top: 1, left: 1, bottom: 1, right: 1), kTTTBackgroundCornerRadiusAttributeName: 3], range: NSRange.init(location: 0, length: authorString.length))
                    }

                    endString.append(by)
                    endString.append(authorString)

                    let attrs = [NSFontAttributeName: FontGenerator.boldFontOfSize(size: 12, submission: true), NSForegroundColorAttributeName: colorF] as [String: Any]

                    let boldString = NSMutableAttributedString(string: "/r/\(submission.crosspostSubreddit)", attributes: attrs)

                    let color = ColorUtil.getColorForSub(sub: submission.crosspostSubreddit)
                    if (color != ColorUtil.baseColor) {
                        boldString.addAttribute(NSForegroundColorAttributeName, value: color, range: NSRange.init(location: 0, length: boldString.length))
                    }

                    endString.append(boldString)
                    finalText.append(endString)

                    b.addTapGestureRecognizer {
                        VCPresenter.openRedditLink(submission.crosspostPermalink, self.parentViewController?.navigationController, self.parentViewController)
                    }
                    info.attributedText = finalText

                } else {
                    let finalText = NSMutableAttributedString.init(string: text, attributes: [NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: FontGenerator.boldFontOfSize(size: 14, submission: true)])
                    finalText.append(NSAttributedString.init(string: "\n\(submission.domain)"))
                    info.attributedText = finalText
                }
            }

        } else {
            b.isHidden = true
            tagbody.isHidden = true
        }

        if (longPress == nil) {
            longPress = UILongPressGestureRecognizer(target: self, action: #selector(LinkTableViewCell.handleLongPress(_:)))
            longPress?.minimumPressDuration = 0.25 // 1 second press
            longPress?.delegate = self
            self.contentView.addGestureRecognizer(longPress!)
        }

    }

    var currentType: CurrentType = .none

    //This function will update constraints if they need to be changed to change the display type
    func doConstraints() {
        var target = CurrentType.none

        if (thumb && !big) {
            target = .thumb
        } else if (big) {
            target = .banner
        } else {
            target = .text
        }

        print(currentType == target)

        if (currentType == target && target != .banner) {
            return //work is already done
        } else if (currentType == target && target == .banner && bigConstraint != nil) {
            self.contentView.addConstraint(bigConstraint!)
            return
        }

        let metrics = ["horizontalMargin": 75, "top": 0, "bottom": 0, "separationBetweenLabels": 0, "full": Int(contentView.frame.size.width), "bannerPadding": (full || SettingValues.postViewMode != .CARD) ? 5 : 0, "size": full ? 16 : 8, "labelMinHeight": 75, "thumb": (SettingValues.largerThumbnail ? 75 : 50), "bannerHeight": submissionHeight] as [String: Int]
        let views = ["label": title, "body": textView, "image": thumbImage, "info": b, "tag": tagbody, "upvote": upvote, "downvote": downvote, "score": score, "comments": comments, "banner": bannerImage, "buttons": buttons, "box": box] as [String: Any]
        var bt = "[buttons]-8-"
        var bx = "[box]-8-"
        if (SettingValues.hideButtonActionbar && !full) {
            bt = "[buttons(0)]-4-"
            bx = "[box(0)]-4-"
        }

        self.contentView.removeConstraints(thumbConstraint)
        thumbConstraint = []

        if (target == .thumb) {
            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[image(thumb)]",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))
            if (SettingValues.leftThumbnail) {
                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-12-[image(thumb)]-8-[label]-12-|",
                        options: NSLayoutFormatOptions(rawValue: 0),
                        metrics: metrics,
                        views: views))
            } else {
                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-12-[label]-8-[image(thumb)]-12-|",
                        options: NSLayoutFormatOptions(rawValue: 0),
                        metrics: metrics,
                        views: views))
            }
            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[label]-10-\(bx)|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))

            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:[image]-(>=5)-\(bt)|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))
        } else if (target == .banner) {
            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:|-[image(0)]",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))
            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-12-[label]-12-|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))

            if (SettingValues.centerLeadImage || full) {
                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[label]-8@999-[banner]-12@999-\(bx)|",
                        options: NSLayoutFormatOptions(rawValue: 0),
                        metrics: metrics,
                        views: views))
                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:[info]-0-[banner]",
                        options: NSLayoutFormatOptions.alignAllLastBaseline,
                        metrics: metrics,
                        views: views))
                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:[banner]-0-[tag]",
                        options: NSLayoutFormatOptions.alignAllLastBaseline,
                        metrics: metrics,
                        views: views))

                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:[info(45)]-8-[buttons]",
                        options: NSLayoutFormatOptions(rawValue: 0),
                        metrics: metrics,
                        views: views))
                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:[info]-8-[box]",
                        options: NSLayoutFormatOptions(rawValue: 0),
                        metrics: metrics,
                        views: views))

                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:[tag]-11-[buttons]",
                        options: NSLayoutFormatOptions(rawValue: 0),
                        metrics: metrics,
                        views: views))
                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:[tag]-11-[box]",
                        options: NSLayoutFormatOptions(rawValue: 0),
                        metrics: metrics,
                        views: views))


            } else {

                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:|-(bannerPadding)-[banner]-8@999-[label]-12@999-\(bx)|",
                        options: NSLayoutFormatOptions(rawValue: 0),
                        metrics: metrics,
                        views: views))
                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:[info(45)]-8@999-[label]",
                        options: NSLayoutFormatOptions(rawValue: 0),
                        metrics: metrics,
                        views: views))
                thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:[tag]-11@999-[label]",
                        options: NSLayoutFormatOptions(rawValue: 0),
                        metrics: metrics,
                        views: views))

            }

            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:\(bt)|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))
            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:\(bx)|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))

            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-(bannerPadding)-[banner]-(bannerPadding)-|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))
            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-(bannerPadding)-[info]-(bannerPadding)-|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))
            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:[tag]-12-|",
                    options: NSLayoutFormatOptions.alignAllLastBaseline,
                    metrics: metrics,
                    views: views))

        } else if (target == .text) {
            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[image(0)]",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))


            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-12-[label]-12-|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))

            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-12-[body]-12-|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))

            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:|-size-[label]-5@1000-[body]-12@1000-\(bx)|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))
            thumbConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:\(bt)|",
                    options: NSLayoutFormatOptions(rawValue: 0),
                    metrics: metrics,
                    views: views))
        }
        self.contentView.addConstraints(thumbConstraint)
        if (target == .banner && bigConstraint != nil) {
            self.contentView.addConstraint(bigConstraint!)
            return
        }
        currentType = target
    }

    public static func checkWiFi() -> Bool {

        let networkStatus = Reachability().connectionStatus()
        switch networkStatus {
        case .Unknown, .Offline:
            return false
        case .Online(.WWAN):
            return false
        case .Online(.WiFi):
            return true
        }
    }

    public static func checkInternet() -> Bool {

        let networkStatus = Reachability().connectionStatus()
        switch networkStatus {
        case .Unknown, .Offline:
            return false
        case .Online(.WWAN):
            return true
        case .Online(.WiFi):
            return true
        }
    }


    func setLinkForPreview(submission: RSubmission) {
        full = false
        lq = false
        self.contentView.backgroundColor = ColorUtil.foregroundColor
        comments.textColor = ColorUtil.fontColor
        title.textColor = ColorUtil.fontColor

        self.link = submission

        title.setText(CachedTitle.getTitle(submission: submission, full: false, false))
        title.sizeToFit()

        reply.isHidden = true
        if (!SettingValues.hideButton) {
            hide.isHidden = true
        } else {
            hide.isHidden = false
        }
        if (!SettingValues.saveButton) {
            save.isHidden = true
        } else {
            save.isHidden = false
        }

        upvote.isHidden = false
        downvote.isHidden = false
        edit.isHidden = true

        thumb = submission.thumbnail
        big = submission.banner
        //todo test if big image
        //todo test if self and hideSelftextLeadImage, don't show anything
        //test if should be LQ, get LQ image instead of banner image
        if (bigConstraint != nil) {
            self.contentView.removeConstraint(bigConstraint!)
        }

        submissionHeight = submission.height

        var type = ContentType.getContentType(baseUrl: submission.url!)
        if (submission.isSelf) {
            type = .SELF
        }

        if (SettingValues.bannerHidden && !full) {
            big = false
            thumb = true
        }


        let fullImage = ContentType.fullImage(t: type)

        if (!fullImage && submissionHeight < 50) {
            big = false
            thumb = true
        } else if (big && (SettingValues.bigPicCropped || full)) {
            submissionHeight = 200
        } else if (big) {
            let h = getHeightFromAspectRatio(imageHeight: submissionHeight, imageWidth: submission.width)
            if (h == 0) {
                submissionHeight = 200
            } else {
                submissionHeight = h
            }
        }

        if (SettingValues.hideButtonActionbar && !full) {
            buttons.isHidden = true
            box.isHidden = true
        }

        if (type == .SELF && SettingValues.hideImageSelftext || SettingValues.hideImageSelftext && !big || type == .SELF && full) {
            big = false
            thumb = false
        }

        if (submissionHeight < 50) {
            thumb = true
            big = false
        }

        let shouldShowLq = false
        if (type == ContentType.CType.SELF && SettingValues.hideImageSelftext
                || SettingValues.noImages && submission.isSelf) {
            big = false
            thumb = false
        }

        if (big || !submission.thumbnail) {
            thumb = false
        }
        if (thumb && type == .SELF) {
            thumb = false
        }


        if (!big && !thumb && submission.type != .SELF && submission.type != .NONE) { //If a submission has a link but no images, still show the web thumbnail
            thumb = true
            addTouch(view: thumbImage, action: #selector(LinkTableViewCell.openLink(sender:)))
            thumbImage.image = UIImage.init(named: "web")
        }

        if (thumb && !big) {
            addTouch(view: thumbImage, action: #selector(LinkTableViewCell.openLink(sender:)))
            if (submission.thumbnailUrl == "nsfw" || (submission.nsfw && !SettingValues.nsfwPreviews)) {
                thumbImage.image = UIImage.init(named: "nsfw")
            } else if (submission.thumbnailUrl == "web" || submission.thumbnailUrl.isEmpty) {
                thumbImage.image = UIImage.init(named: "web")
            } else {
                thumbImage.sd_setImage(with: URL.init(string: submission.thumbnailUrl), placeholderImage: UIImage.init(named: "web"))
            }
        } else {
            thumbImage.sd_setImage(with: URL.init(string: ""))
            self.thumbImage.frame.size.width = 0
        }


        if (big) {
            bannerImage.alpha = 0
            let imageSize = CGSize.init(width: submission.width, height: full ? 200 : submission.height);
            var aspect = imageSize.width / imageSize.height
            if (aspect == 0 || aspect > 10000 || aspect.isNaN) {
                aspect = 1
            }
            if (!full) {
                bigConstraint = NSLayoutConstraint(item: bannerImage, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: bannerImage, attribute: NSLayoutAttribute.height, multiplier: aspect, constant: 0.0)
            } else {
                aspect = self.contentView.frame.size.width / 200
                submissionHeight = 200
                bigConstraint = NSLayoutConstraint(item: bannerImage, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: bannerImage, attribute: NSLayoutAttribute.height, multiplier: aspect, constant: 0.0)

            }
            bannerImage.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(LinkTableViewCell.openLink(sender:)))
            tap.delegate = self
            bannerImage.addGestureRecognizer(tap)
            if (shouldShowLq) {
                bannerImage.sd_setImage(with: URL.init(string: submission.lqUrl), completed: { (image, error, cache, url) in
                    self.bannerImage.contentMode = .scaleAspectFill
                    if (cache == .none) {
                        UIView.animate(withDuration: 0.3, animations: {
                            self.bannerImage.alpha = 1
                        })
                    } else {
                        self.bannerImage.alpha = 1
                    }
                })
            } else {
                bannerImage.sd_setImage(with: URL.init(string: submission.bannerUrl), completed: { (image, error, cache, url) in
                    self.bannerImage.contentMode = .scaleAspectFill
                    if (cache == .none) {
                        UIView.animate(withDuration: 0.3, animations: {
                            self.bannerImage.alpha = 1
                        })
                    } else {
                        self.bannerImage.alpha = 1
                    }
                })
            }
        } else {
            bannerImage.sd_setImage(with: URL.init(string: ""))
        }

        comments.text = " \(submission.commentCount)"

        doConstraints()

        refresh()


        if (type != .IMAGE && type != .SELF && !thumb) {
            b.isHidden = false
            var text = ""
            switch (type) {
            case .ALBUM:
                text = ("Album")
                break
            case .EXTERNAL:
                text = "External Link"
                break
            case .LINK, .EMBEDDED, .NONE:
                text = "Link"
                break
            case .DEVIANTART:
                text = "Deviantart"
                break
            case .TUMBLR:
                text = "Tumblr"
                break
            case .XKCD:
                text = ("XKCD")
                break
            case .GIF:
                text = ("GIF")
                break
            case .IMGUR:
                text = ("Imgur")
                break
            case .VIDEO:
                text = "YouTube"
                break
            case .STREAMABLE:
                text = "Streamable"
                break
            case .VID_ME:
                text = ("Vid.me")
                break
            case .REDDIT:
                text = ("Reddit content")
                break
            default:
                text = "Link"
                break
            }
            if (SettingValues.smallerTag && !full) {
                b.isHidden = true
                tagbody.isHidden = false
                taglabel.text = " \(text.uppercased()) "
            } else {
                tagbody.isHidden = true
                let finalText = NSMutableAttributedString.init(string: text, attributes: [NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: FontGenerator.boldFontOfSize(size: 14, submission: true)])
                finalText.append(NSAttributedString.init(string: "\n\(submission.domain)"))
                info.attributedText = finalText
            }

        } else {
            b.isHidden = true
        }
    }

    var longPress: UILongPressGestureRecognizer?
    var timer: Timer?
    var cancelled = false

    func showMore() {
        timer!.invalidate()
        AudioServicesPlaySystemSound(1519)
        if (!self.cancelled) {
            self.more()
        }
    }

    func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        if (sender.state == UIGestureRecognizerState.began) {
            cancelled = false
            timer = Timer.scheduledTimer(timeInterval: 0.25,
                    target: self,
                    selector: #selector(self.showMore),
                    userInfo: nil,
                    repeats: false)


        }
        if (sender.state == UIGestureRecognizerState.ended) {
            timer!.invalidate()
            cancelled = true
        }
    }

    func refresh() {
        let link = self.link!
        upvote.image = UIImage.init(named: "upvote")?.menuIcon()
        save.image = UIImage.init(named: "save")?.menuIcon()
        downvote.image = UIImage.init(named: "downvote")?.menuIcon()
        var attrs: [String: Any] = [:]
        switch (ActionStates.getVoteDirection(s: link)) {
        case .down:
            downvote.image = UIImage.init(named: "downvote")?.withColor(tintColor: ColorUtil.downvoteColor).imageResize(sizeChange: CGSize.init(width: 20, height: 20))
            attrs = ([NSForegroundColorAttributeName: ColorUtil.downvoteColor, NSFontAttributeName: FontGenerator.boldFontOfSize(size: 12, submission: true)])
            break
        case .up:
            upvote.image = UIImage.init(named: "upvote")?.withColor(tintColor: ColorUtil.upvoteColor).imageResize(sizeChange: CGSize.init(width: 20, height: 20))
            attrs = ([NSForegroundColorAttributeName: ColorUtil.upvoteColor, NSFontAttributeName: FontGenerator.boldFontOfSize(size: 12, submission: true)])
            break
        default:
            attrs = ([NSForegroundColorAttributeName: ColorUtil.fontColor, NSFontAttributeName: FontGenerator.fontOfSize(size: 12, submission: true)])
            break
        }


        if (full) {
            let subScore = NSMutableAttributedString(string: (link.score >= 10000 && SettingValues.abbreviateScores) ? String(format: " %0.1fk", (Double(link.score) / Double(1000))) : " \(link.score)", attributes: attrs)
            let scoreRatio =
                    NSMutableAttributedString(string: (SettingValues.upvotePercentage && full && link.upvoteRatio > 0) ?
                            " (\(Int(link.upvoteRatio * 100))%)" : "", attributes: [NSFontAttributeName: comments.font, NSForegroundColorAttributeName: comments.textColor])

            var attrsNew: [String: Any] = [:]
            if (scoreRatio.length > 0) {
                let numb = (link.upvoteRatio)
                if (numb <= 0.5) {
                    if (numb <= 0.1) {
                        attrsNew = [NSForegroundColorAttributeName: GMColor.blue500Color()]
                    } else if (numb <= 0.3) {
                        attrsNew = [NSForegroundColorAttributeName: GMColor.blue400Color()]
                    } else {
                        attrsNew = [NSForegroundColorAttributeName: GMColor.blue300Color()]
                    }
                } else {
                    if (numb >= 0.9) {
                        attrsNew = [NSForegroundColorAttributeName: GMColor.orange500Color()]
                    } else if (numb >= 0.7) {
                        attrsNew = [NSForegroundColorAttributeName: GMColor.orange400Color()]
                    } else {
                        attrsNew = [NSForegroundColorAttributeName: GMColor.orange300Color()]
                    }
                }
            }

            scoreRatio.addAttributes(attrsNew, range: NSRange.init(location: 0, length: scoreRatio.length))

            subScore.append(scoreRatio)
            score.attributedText = subScore
        } else {
            score.text = (link.score >= 10000 && SettingValues.abbreviateScores) ? String(format: " %0.1fk", (Double(link.score) / Double(1000))) : " \(link.score)"
        }


        if (ActionStates.isSaved(s: link)) {
            save.image = UIImage.init(named: "save")?.withColor(tintColor: GMColor.yellow500Color()).imageResize(sizeChange: CGSize.init(width: 20, height: 20))
        }
        if (History.getSeen(s: link) && !full) {
            self.title.alpha = 0.7
        } else {
            self.title.alpha = 1
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        var topmargin = 0
        var bottommargin = 2
        var leftmargin = 0
        var rightmargin = 0

        if (SettingValues.postViewMode == .CARD && !full) {
            topmargin = 5
            bottommargin = 5
            leftmargin = 5
            rightmargin = 5
            self.contentView.elevate(elevation: 2)
        }

        let f = self.contentView.frame
        let fr = UIEdgeInsetsInsetRect(f, UIEdgeInsetsMake(CGFloat(topmargin), CGFloat(leftmargin), CGFloat(bottommargin), CGFloat(rightmargin)))
        self.contentView.frame = fr
    }


    var registered: Bool = false

    func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                           viewControllerForLocation location: CGPoint) -> UIViewController? {
        if (full) {
            let locationInTextView = textView.convert(location, to: textView)

            if let (url, rect) = getInfo(locationInTextView: locationInTextView) {
                previewingContext.sourceRect = textView.convert(rect, from: textView)
                if let controller = parentViewController?.getControllerForUrl(baseUrl: url) {
                    return controller
                }
            }
        } else {
            if let controller = parentViewController?.getControllerForUrl(baseUrl: (link?.url)!) {
                return controller
            }
        }
        return nil
    }

    func getInfo(locationInTextView: CGPoint) -> (URL, CGRect)? {
        if let attr = textView.link(at: locationInTextView) {
            return (attr.result.url!, attr.accessibilityFrame)
        }
        return nil
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        if (viewControllerToCommit is WebsiteViewController || viewControllerToCommit is SFHideSafariViewController || viewControllerToCommit is SingleSubredditViewController || viewControllerToCommit is UINavigationController || viewControllerToCommit is CommentViewController) {
            parentViewController?.show(viewControllerToCommit, sender: nil)
        } else {
            parentViewController?.present(viewControllerToCommit, animated: true)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var parentViewController: MediaViewController?
    public var navViewController: UIViewController?

    func openLink(sender: UITapGestureRecognizer? = nil) {
        (parentViewController)?.setLink(lnk: link!, shownURL: loadedImage, lq: lq, saveHistory: true) //todo check this
    }

    func openComment(sender: UITapGestureRecognizer? = nil) {
        if (!full) {
            let comment = CommentViewController(submission: link!)

            if ((self.navViewController as? UINavigationController)?.splitViewController != nil && !SettingValues.multiColumn) {
                let nav = UINavigationController(rootViewController: comment)
                (self.navViewController as? UINavigationController)?.splitViewController?.showDetailViewController(nav, sender: nil)
            } else {
                VCPresenter.showVC(viewController: comment, popupIfPossible: true, parentNavigationController: parentViewController?.navigationController, parentViewController: parentViewController)
            }
        }
    }

    public static var imageDictionary: NSMutableDictionary = NSMutableDictionary.init()

}