//MainView.qml
//import Qt 4.7
import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.0

Page {
    id : mainView
    anchors.fill : parent
    tools : mainViewToolBar

    property int maxPageNumber : 2
    property int pageNumber : 1
    property string mangaPath : ""
    property string lastUrl

    onMangaPathChanged : { reloadPage() }
    onPageNumberChanged : { reloadPage() }

    function reloadPage() {
        //console.log("** reloading page **")
        var pageIndex = pageNumber-1
        var url = "image://page/" + mangaPath + "|" + pageIndex;
        // check for false alarms
        if (url != lastUrl) {
          //console.log(mangaPath + " " + pageNumber)
          mangaPage.source = url
          // reset the page position
          pageFlickable.contentX = 0;
          pageFlickable.contentY = 0;
          //update page number in the current manga instance
          //NOTE: this is especialy important due to the slider
          readingState.setPageID(pageIndex);
          }
        }

    ToolBarLayout {
        id : mainViewToolBar
        visible: false
        ToolIcon { iconId: "toolbar-view-menu"; onClicked: mainViewMenu.open() }
        //ToolIcon { iconId: "toolbar-previous" }
        ToolButton { id : pageNumbers
                     //text : 0/1
                     text : mainView.pageNumber + "/" + mainView.maxPageNumber
                     height : parent.height
                     flat : true
                     onClicked : { pagingDialog.open() }
                   }
        //ToolIcon { iconId: "toolbar-next" }
        ToolIcon { iconId: "toolbar-next"
                   rotation : 90
                   onClicked: mainView.toggleFullscreen() }
        //ToolIcon { iconSource: "image://icons/view-normal.png"; onClicked: mainView.toggleFullscreen() }
        }

    Menu {
        id : mainViewMenu

        MenuLayout {
            MenuItem {
              text : "Open file"
              onClicked : {                   
                  fileSelector.down(readingState.getSavedFileSelectorPath());
                  fileSelector.open();
                  }
              }

            MenuItem {
                text : "History"
                onClicked : {
                    console.log("implement history");
                    }
                }

            MenuItem {
                text : "Options"
                onClicked : {
                    console.log("implement options");
                    }
                }

            MenuItem {
                text : "About"
                onClicked : {
                    console.log("implement about");
                    }
                }
            }
        }

    function showPage(path, pageId) {
        mainView.mangaPath = path
        var pageNr = pageId+1
        mainView.pageNumber = pageNr
        }

    // ** trigger notifications
    function notify(text) {
        notification.text = text;
        notification.show();
        }

    // ** fullscreen handling
    function toggleFullscreen() {
        console.log("toggle toolbar");
        /* handle fullscreen button hiding
        it should be only visible with no toolbar */
        fullscreenButton.visible = !fullscreenButton.visible
        rootWindow.showToolBar = !rootWindow.showToolBar;
        }

    MouseArea {
        anchors.fill : parent
        id: prevButton
        objectName: "prevButton"
        drag.filterChildren: true
        onClicked: {
            if (mouseX < width/2.0){
                console.log("previous");
                readingState.previous();
                }

            else{
                console.log("next");
                readingState.next();
                }
        }

        Flickable {
            id: pageFlickable
            objectName: "pageFlickable"
            anchors.fill : parent
            contentWidth: mangaPage.width
            contentHeight: mangaPage.height

            Image {
                id: mangaPage
                //PinchArea {
                //    pinch.target : pageFlickable
                //    }
                }
            }
       }

    Image {
        id : fullscreenButton
        source : "image://icons/view-fullscreen.png"
        anchors.right : mainView.right
        anchors.bottom : mainView.bottom
        visible : false
        opacity : 0.1
        width : Math.min(parent.width,parent.height)/8.0
        height : Math.min(parent.width,parent.height)/8.0
        MouseArea {
            anchors.fill : parent
            drag.filterChildren: true
            onClicked: mainView.toggleFullscreen();
            }
        }

    Menu {
        id : pagingDialog
        Row {
            Slider {
                //width : pagingColumn.width*0.8
                //anchors.topMargin : height*0.5
                id : pagingSlider
                maximumValue: mainView.maxPageNumber
                minimumValue: 1
                value: mainView.pageNumber
                stepSize: 1
                valueIndicatorVisible: false
                //orientation : Qt.Vertical
                onPressedChanged : {
                    //only load the page once the user stopped dragging to save resources
                    mainView.pageNumber = value
                    }

                }

            CountBubble {
                value : pagingSlider.value
                largeSized : true
                }
            }
        }
    }