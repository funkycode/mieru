//MainView.qml
import Qt 4.7
import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.0

Page {
    id : mainView
    objectName : "mainView"
    anchors.fill : parent
    tools : mainViewToolBar

    property int maxPageNumber : 1
    property int pageNumber : 1
    property string mangaPath : ""
    property string lastUrl
    property bool pageLoaded : false
    property bool rememberScale  : options.get("QMLRememberScale", false)
    property bool pagingFeedback : options.get("QMLPagingFeedback", true)
    property string pagingMode   : options.get("QMLPagingMode", "screen")
    property string pageFitMode  : options.get("fitMode", "original")
    property alias fullscreenButtonOpacity : fullscreenButton.opacity

    onMangaPathChanged  : reloadPage()
    onPageNumberChanged : reloadPage()

    // workaround for calling python properties causing segfaults
    function shutdown() {
        //console.log("main view shutting down")
    }

    function reloadPage() {
        //console.log("** reloading page **")
        var pageIndex = pageNumber - 1
        var url = "image://page/" + mangaPath + "|" + pageIndex
		
        // check for false alarms
        if (url != lastUrl) {
          //console.log(mangaPath + " " + pageNumber)
          mangaPage.source = url

          // reset the page position
          pageFlickable.contentX = 0
          pageFlickable.contentY = 0

          // in manga mode reading starts from right - so adjust the initial flick
          if((rootWindow.enableMangaMode) && (mangaPage.width > mainView.width)) {
              pageFlickable.contentX = mangaPage.width - mainView.width;
          }

          // update page number in the current manga instance
          // NOTE: this is especially important due to the slider
          readingState.setPageID(pageIndex, mangaPath)
          pageLoaded = true
        }
     }

    function showPage(path, pageId) {
        mainView.mangaPath  = path
        mainView.pageNumber = pageId + 1
    }

    function restoreContentShift(){
        /* check if restored scale is consistent
           between the independently saved value and the
           value remembered in the manga state
        */
        var mangaStateScale = readingState.getActiveMangaScale()
        if (mangaStateScale == pageFlickable.scale) {
            pageFlickable.contentX = readingState.getActiveMangaShiftX()
            pageFlickable.contentY = readingState.getActiveMangaShiftY()
        }
    }
	
    function toggleFullscreen() {
        // fullscreen button shall only be visible if the toolbar is hidden
        rootWindow.showToolBar   = !rootWindow.showToolBar;
        fullscreenButton.visible = !rootWindow.showToolBar;
        options.set("QMLToolbarState", rootWindow.showToolBar)
    }

    function getScale() {
        return pageFlickable.scale
    }

    function getXShift() {
        return pageFlickable.contentX
    }

    function getYShift() {
        return pageFlickable.contentY
    }

    // restore possible saved rotation lock value
    function restoreRotation() {
        var savedRotation = options.get("QMLmainViewRotation", "auto")
        if ( savedRotation == "auto" ) {
            mainView.orientationLock = PageOrientation.Automatic
        } else if ( savedRotation == "portrait" ) {
            mainView.orientationLock = PageOrientation.LockPortrait
        } else {
            mainView.orientationLock = PageOrientation.LockLandscape
        }
    }

    function showPrevFeedback() {
        // only show with feedback enabled and no feedback in progress
        if (mainView.pagingFeedback && !prevFbTimer.running) {
            prevFbTimer.start()
        }
    }

    function showNextFeedback() {
        // only show with feedback enabled and no feedback in progress
        if (mainView.pagingFeedback && !nextFbTimer.running) {
            nextFbTimer.start()
        }
    }

    /** Page fitting **/

    function setPageFitMode(fitMode) {
        // set page fitting - only update on a mode change
        if (fitMode != mainView.pageFitMode) {
            options.set("fitMode", fitMode)
            mainView.pageFitMode = fitMode
        }
        // scale remembering for:
        // * disable for non-custom fitting modes
        // * enable for custom fitting mode
        var remember = (fitMode == "custom")
        mainView.rememberScale = remember
        options.set("QMLRememberScale", remember)
    }

    onPageFitModeChanged : {
        // trigger page refit
        fitPage(pageFitMode)
    }

    // handle viewport resize
    onWidthChanged : {
        //console.log("mw width " + width)
        fitPage(pageFitMode)
    }
    onHeightChanged : {
        //console.log("mw height " + height)
        fitPage(pageFitMode)
    }

    function fitPage(mode) {
        // translateable strings are marked up using QT_TR_NOOP()
        // the actual translation is located in the paging dialog
    
        // fit the page according to the current fitting mode
        if (mode == QT_TR_NOOP("original")) {
            pageFlickable.scale = 1.0
        } else if (mode == QT_TR_NOOP("width")) {
            pageFlickable.scale = mainView.width  / mangaPage.sourceSize.width
        } else if (mode == QT_TR_NOOP("height")) {
            pageFlickable.scale = mainView.height / mangaPage.sourceSize.height
        } else if (mode == QT_TR_NOOP("screen")) {
            fitPageToScreen()
        } else if (mode == QT_TR_NOOP("orient")) {
            // fit to screen in portrait, fit to width in landscape
            if (rootWindow.inPortrait) {
                fitPageToScreen()
            } else {
                pageFlickable.scale = mainView.width/mangaPage.sourceSize.width
            }
        } else if (mode == QT_TR_NOOP("most")) {
            // fit fo to the longest side of the image
            if (pageFlickable.width >= pageFlickable.height) {
                pageFlickable.scale = mainView.width / mangaPage.sourceSize.width
            } else {
                pageFlickable.scale = mainView.height / mangaPage.sourceSize.height
            }
        }
        else if(mode == QT_TR_NOOP("custom")) {
            /* nothing needs to be done for the custom mode
               as the current scale is just used as the initial
               custom scale */        
        }
    }

    function fitPageToScreen() {
        // image
        var wi = mangaPage.sourceSize.width
        var hi = mangaPage.sourceSize.height
        var ri = wi / hi
        // screen
        var ws = mainView.width
        var hs = mainView.height
        var rs = ws / hs
        if (rs > ri) {
            pageFlickable.scale = (wi * hs / hi) / wi
        } else {
            pageFlickable.scale = ws/wi
        }
    }

    Component.onCompleted : restoreRotation()

    /** Toolbar **/

    ToolBarLayout {
        id : mainViewToolBar
        visible: false
        ToolIcon {
            // FIXME: incomplete theme on Fremantle
            iconId: platform.incompleteTheme() ?
            "icon-m-common-next" : "toolbar-down"
            rotation : platform.incompleteTheme() ? 90 : 0
            onClicked: mainView.toggleFullscreen()
        }
        ToolButton {
            id : pageNumbers
            text : mainView.pageLoaded ? mainView.pageNumber + "/" + mainView.maxPageNumber : "-/-"
            anchors.top : backTI.top
            anchors.bottom : backTI.bottom
            flat : true
            onClicked : pagingDialog.open()
        }
        ToolIcon {
            id : backTI
            iconId: "toolbar-view-menu"
            onClicked: mainViewMenu.open()
        }
    }

    /** Main menu **/

    Menu {
        id : mainViewMenu
        MenuLayout {
            id : mainLayout
            MenuItem {
                text : qsTr("Open file")
                onClicked : {
                    fileSelector.down(readingState.getSavedFileSelectorPath());
                    fileSelector.open();
                }
            }
            MenuItem {
                text : qsTr("History")
                onClicked : rootWindow.openFile("HistoryPage.qml")
            }
            MenuItem {
                text : qsTr("Info")
                onClicked : rootWindow.openFile("InfoPage.qml")
            }
            MenuItem {
                text : qsTr("Options")
                onClicked : rootWindow.openFile("OptionsPage.qml")
            }
            // TODO: shall this be really platform dependent?
            //       using 'visible' property does not look good
            MenuItem {
                id : quitButton
                text : qsTr("Quit")
                onClicked : readingState.quit()
            }
            Component.onCompleted : {
                // don't show the Quit button on platforms
                // where it is not needed
                if (!platform.showQuitButton()) {
                    quitButton.destroy()
                }
            }
        }
    }

    /** Pinch zoom **/

    PinchArea {
        //anchors.fill : parent
        //onPinchStarted : console.log("pinch started")
        //pinch.target : mangaPage
        //pinch.minimumScale: 0.5
        //pinch.maximumScale: 2
        width: Math.max(pageFlickable.contentWidth, pageFlickable.width)
        height: Math.max(pageFlickable.contentHeight, pageFlickable.height)
        property real initialScale
        property real initialWidth
        property real initialHeight

        onPinchStarted: {
            initialScale = pageFlickable.scale
            initialWidth = pageFlickable.contentWidth
            initialHeight = pageFlickable.contentHeight
            //pageFlickable.interactive = false
            //console.log("start " + pinch.scale)
        }

        onPinchUpdated: {
            // adjust content pos due to drag
            pageFlickable.contentX += pinch.previousCenter.x - pinch.center.x
            pageFlickable.contentY += pinch.previousCenter.y - pinch.center.y

            // resize content
            pageFlickable.resizeContent(initialWidth * pinch.scale, initialHeight * pinch.scale, pinch.center)
            // remember current scale
            pageFlickable.scale = initialScale * pinch.scale

            //console.log("pf " + pageFlickable.contentWidth + " " + pageFlickable.contentHeight)
            //console.log("page " + mangaPage.width + " " + mangaPage.height)
            //console.log("scale " + pageFlickable.scale)
        }

        onPinchFinished: {
            //pageFlickable.interactive = true
            // move its content within bounds
            pageFlickable.returnToBounds()
            if (mainView.rememberScale) {
                // save the new scale so that it can
                // be used on the next page
                options.set("QMLMangaPageScale", pageFlickable.scale)
                // override page fitting with the new scale
                if (mainView.pageFitMode != "custom") {
                    mainView.setPageFitMode("custom")
                }
            }
        }
    }

    /** Left/right screen half page switching **/

    MouseArea {
        anchors.fill : parent
        id: prevButton
        objectName: "prevButton"
        drag.filterChildren: true
        onClicked: {
            // default to screen paging mode
            var margin = width / 2;

            if(mainView.pagingMode == "screen") {
                // nothing to do here - default behaviour
            }
            else if(mainView.pagingMode == "edges") {
                // do not use the full screen area for page switching
                if(rootWindow.inPortrait) {
                    // margin is bigger for portrait mode
                    margin = width * 0.30;
                }
                else {
                    margin = width * 0.20;
                }
            }

            if (mouseX < margin) {
                mainView.showPrevFeedback()
                console.log("previous page");
                readingState.previous();
            }

            if (mouseX > (width - margin)) {
                mainView.showNextFeedback()
                console.log("next page");
                readingState.next();
            }
        }

        /** Main manga page flickable **/

        Flickable {
            id: pageFlickable
            property real scale: mainView.rememberScale ? options.get("QMLMangaPageScale", 1.0) : 1.0
            objectName: "pageFlickable"
            anchors.fill : parent
            // center the page if it is smaller than the viewport
            anchors.leftMargin : (contentWidth < mainView.width) ? (mainView.width-contentWidth)/2.0 : 0
            anchors.topMargin  : (contentHeight < mainView.height) ? (mainView.height-contentHeight)/2.0 : 0
            contentWidth  : mangaPage.width
            contentHeight : mangaPage.height
            
            /*
            clipping seems to lead to performance degradation so it is only enabled
            once the GUI-page transition starts to prevent the manga-page overlapping
            the new GUI-page during transition
            */
            clip : rootWindow.pageStack.busy

            Image {
                id: mangaPage
                width : sourceSize.width * pageFlickable.scale
                height : sourceSize.height * pageFlickable.scale
                smooth : true
                fillMode : Image.PreserveAspectFit
                
                onSourceSizeChanged : {
                    if (mainView.pageFitMode != "custom") {
                        mainView.fitPage(mainView.pageFitMode)
                    }
                }
            }
        }
    }

    /** Fullscreen toggle button **/

    ToolIcon {
        id : fullscreenButton
        // FIXME: incomplete theme on Fremantle
        iconId: platform.incompleteTheme() ?
        "icon-m-common-next" : "toolbar-up"
        rotation : platform.incompleteTheme() ? 270 : 0
        anchors.left   : mainView.left
        anchors.bottom : mainView.bottom
        anchors.leftMargin : 10
        visible : !rootWindow.showToolBar
        opacity : options.get("QMLFullscreenButtonOpacity", 0.5)
        width   : Math.min(parent.width, parent.height) / 8.0
        height  : Math.min(parent.width, parent.height) / 8.0
        MouseArea {
            anchors.fill : parent
            drag.filterChildren: true
            onClicked: mainView.toggleFullscreen();
        }
    }

    /** Quick menu **/

    Menu {
        id : pagingDialog
        MenuLayout {
            id : mLayout

            Column {
                spacing : 10
                Slider {
                    id : pagingSlider
                    width : mLayout.width
                    maximumValue: mainView.maxPageNumber
                    minimumValue: 1
                    value: mainView.pageNumber
                    stepSize: 1
                    valueIndicatorVisible: false
                    onPressedChanged : {
                        // only load the page once the user stopped dragging to save resources
                        mainView.pageNumber = value
                    }
                }
                CountBubble {
                    anchors.horizontalCenter : parent.horizontalCenter
                    value : pagingSlider.value
                    largeSized : true
                }
                Button {
                    width : mLayout.width
                    text  : qsTr(mainView.pageFitMode)
                    // FIXME: incomplete theme on Fremantle
                    iconSource: platform.incompleteTheme() ?
                    "image://theme/icon-m-image-edit-resize" : "image://theme/icon-m-image-expand"
                    onClicked : pageFitSelector.open()
                }
                Button {
                    width : mLayout.width
                    text  : qsTr("Rotation")
                    iconSource : "image://theme/icon-m-common-" + __iconType
                    property string __iconType: (mainView.orientationLock == PageOrientation.LockPrevious) ? "locked" : "unlocked"
                    onClicked: {
                        if (mainView.orientationLock == PageOrientation.LockPrevious) {
                            mainView.orientationLock = PageOrientation.Automatic
                        } else {
                            mainView.orientationLock = PageOrientation.LockPrevious
                        }
                    }
                }
            }
        }
    }

    /** No pages loaded label **/

    Label {
        anchors.centerIn : parent
        text : "<h1>" + qsTr("No pages loaded") + "</h1>"
        visible : !mainView.pageLoaded
    }

    /** Paging feedback **/

    Item {
        id : previousFeedback
        visible : false
        opacity : 0.7
        anchors.fill : parent
        Rectangle {
            id : previousRect
            anchors.top    : parent.top
            anchors.bottom : parent.bottom
            anchors.left   : parent.left
            width : previousIcon.width + 40
            color : "darkgray"
        }
        Image {
            id : previousIcon
            anchors.verticalCenter : parent.verticalCenter
            anchors.left : parent.left
            anchors.leftMargin : 20
            source : "image://theme/icon-m-toolbar-previous"
        }
    }
    Item {
        id : nextFeedback
        visible : false
        opacity : 0.7
        anchors.fill : parent
        Rectangle {
            id : nextRect
            anchors.top    : parent.top
            anchors.bottom : parent.bottom
            anchors.right  : parent.right
            width : nextIcon.width + 40
            color : "darkgray"
        }
        Image {
            id : nextIcon
            anchors.verticalCenter : parent.verticalCenter
            anchors.right : parent.right
            anchors.rightMargin : 20
            source : "image://theme/icon-m-toolbar-next"
        }
    }

    Timer {
        id : prevFbTimer
        interval : 500
        triggeredOnStart : true
        onTriggered : previousFeedback.visible = !previousFeedback.visible
    }
	
    Timer {
        id : nextFbTimer
        interval : 500
        triggeredOnStart : true
        onTriggered : nextFeedback.visible = !nextFeedback.visible
    }

    /** Optional Minimise button for Maemo **/

    Image {
        id : minimiseButton
        visible: rootWindow.showToolBar && platform.showMinimiseButton()
        anchors.top : mainView.top
        anchors.left : mainView.left
        anchors.topMargin  : 10
        anchors.leftMargin : 10
        source : "image://icons/switch.png"
        width  : 48
        height : 48
        MouseArea {
            anchors.fill : parent
            onClicked    : platform.minimise()
        }
    }
}
