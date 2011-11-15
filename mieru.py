#!/usr/bin/env python

import time

# Mieru modules import
import manga
import options
import startup
import stats
import gui
# append the platform modules folder to path
import sys
sys.path.append('platforms')

class Mieru:

  def destroy(self):
    # log elapsed time
    sessionTime = time.time() - self.startupTimeStamp
    self.stats.updateUsageTime(sessionTime)

    self.saveState()
    self.options.save()
    print "mieru quiting"
    self.gui.stopMainLoop()

  def __init__(self):
    # log start
    self.startupTimeStamp = time.time()

    # parse startup arguments
    start = startup.Startup()
    args = start.args


    # restore persistent options
    self.d = {}
    self.options = options.Options(self)
    # options value watching
    self.maxWatchId = 0
    self.watches = {}

    # enable stats
    self.stats = stats.Stats(self)

    self.continuousReading = True

    initialSize = (800,480)

    # create the GUI
    if args.u == "hildon":
      self.gui = gui.getGui(self, 'hildon', accel=True, size=initialSize)
    if args.u == "harmattan" or args.u=='QML':
      self.gui = gui.getGui(self, 'QML', accel=True, size=initialSize)
    else:
      self.gui = gui.getGui(self, 'GTK', accel=True, size=initialSize)

#    # resize the viewport when window size changes
#    self.gui.resizeNotify(self._resizeViewport)

    # get the platform module
    if args.u == "hildon":
      import maemo5
      self.platform = maemo5.Maemo5(self)
    elif args.u == "harmattan":
      import harmattan
      self.platform = harmattan.Harmattan(self)

    else:
      import pc
      self.platform = pc.PC(self)

    self.activeManga = None

    # check if a path was specified in the startup arguments
    if args.o != None:
      try:
        print("loading manga from: %s" % args.o)
        self.activeManga = self.openManga(args.o)
        print('manga loaded')
      except Exception, e:
        print("loading manga from path: %s failed" % args.o)
        print(e)


    #self.openManga("/home/user/MyDocs/manga/ubunchu/ubunchu.zip")
    """ restore previously saved state (if available and no manga was 
    susscessfully loaded from a path provided by startup arguments"""
    if self.activeManga == None:
      self._restoreState()

#    self.gui.toggleFullscreen()

    # start the main loop
    self.gui.startMainLoop()

  def getDict(self):
    return self.d

  def setDict(self, d):
    self.d = d

  def getViewport(self):
    return self.viewport

  def getWindow(self):
    return self.window

  def getVbox(self):
    return self.vbox

  def getActiveManga(self):
    return self.activeManga

  def keyPressed(self, keyName):
    if keyName == 'f':
      self.gui.toggleFullscreen()
    elif keyName == 'o':
      self.notify('fit to <b>original size</b>')
      self.set('fitMode',"original")
    elif keyName == 'i':
      self.notify('fit to <b>width</b>')
      self.set('fitMode',"width")
    elif keyName == 'u':
      self.notify('fit to <b>height</b>')
      self.set('fitMode',"height")
    elif keyName == 'z':
      self.notify('fit to <b>screen</b>')
      self.set('fitMode', "screen")
    elif keyName == 'n':
      """launch file chooser"""
      self.platform.startChooser("file")
    elif keyName == 'b':
      """launch folder chooser"""
      self.platform.startChooser("folder")
    elif keyName == 'k':
      """toggle kinetic scrolling"""
      kinetic = self.get('kineticScrolling', True)
      if kinetic:
        self.set('kineticScrolling', False)
        self.notify('kinetic scrolling <b>disabled</b>')
      else:
        self.set('kineticScrolling', True)
        self.notify('kinetic scrolling <b>enabled</b>')
    elif keyName == 'p':
      """show paging dialog"""
      self.platform.showPagingDialog()
    elif keyName == 'c':
      """show options window"""
      self.platform.showOptions()
    elif keyName == 'a':
      """show info window"""
      self.platform.showInfo()
    elif keyName == 'm':
      """minimize the main window"""
      self.platform.minimize()
    elif keyName == 'q':
      self.destroy(self.window)
    elif keyName == 'F8' or keyName == 'Page_Up':
      if self.activeManga:
        self.activeManga.previous()
    elif keyName == 'F7' or keyName == 'Page_Down':
      if self.activeManga:
        self.activeManga.next()
    elif not self.platform.handleKeyPress(keyName):
      print "key: %s" % keyName

  def on_button_press_event(actor, event):
    print "button press event"

  def notify(self, message, icon=""):
    print "notification: %s" % message
    self.platform.notify(message,icon)

  def openManga(self, path, startOnPage=0, replaceCurrent=True, loadNotify=True):
    if replaceCurrent:
      if self.activeManga:
        print "closing previously open manga"
        self.activeManga.close()

      print "opening %s on page %d" % (path,startOnPage)
      self.activeManga = manga.Manga(self, path, startOnPage, loadNotify=loadNotify)
      mangaState = self.activeManga.getState()
      # increment count
      self.stats.incrementUnitCount()

      self.addToHistory(mangaState)
      self.saveState()
      return self.activeManga
    else:
      return manga.Manga(self, path, startOnPage)


  def openMangaFromState(self, state):
    if self.activeManga:
      print "closing previously open manga"
      self.activeManga.close()

    print "opening manga from state"
    #print state
    self.activeManga = manga.Manga(self,load=False)
    self.activeManga.setState(state)

    mangaState = self.activeManga.getState()
    self.addToHistory(mangaState)
    self.saveState()

  def getActiveMangaPath(self):
    if self.activeManga:
      return self.activeManga.getPath()

  def addToHistory(self,mangaState):
    """add a saved manga state to the history"""
    openMangasHistory = self.get('openMangasHistory',None)
    if openMangasHistory == None: # history has not yet taken place
      openMangasHistory = {}

    if mangaState['path'] != None:
      path = mangaState['path']
      print "adding to history: %s" % path
      openMangasHistory[path] = {"state":mangaState,"timestamp":time.time()}
      """the states are saved under their path to store only unique mangas,
         when the same manga is opened again, its state is replaced by the new one
         the timestamp is used for chrnological sorting of the list
      """
    # save the history back to the persistant store
    # TODO: limit the size of the history + clearing of history
    self.set('openMangasHistory', openMangasHistory)

  def addMangaToHistory(self, manga):
    """add a manga instance to history"""
    state = manga.getState()
    if state:
      self.addToHistory(state)

  def removeMangaFromHistory(self,path):
    """delete manga described by path from history"""
    openMangasHistory = self.get('openMangasHistory',None)
    if openMangasHistory:
      if path in openMangasHistory:
        del openMangasHistory[path]
    self.set('openMangasHistory', openMangasHistory)

  def getSortedHistory(self):
    openMangasHistory = self.get('openMangasHistory',None)
    if openMangasHistory:
      sortedList = []
      for path in sorted(openMangasHistory, key=lambda path: openMangasHistory[path]['timestamp'], reverse=True):
        sortedList.append(openMangasHistory[path])
      return sortedList
    else:
      return None

  def clearHistory(self):
    """clear the history of opened mangas"""
    self.set('openMangasHistory', {})


  def watch(self, key, callback, *args):
    """add a callback on an options key"""
    id = self.maxWatchId + 1 # TODO remove watch based on id
    self.maxWatchId = id # TODO: recycle ids ? (alla PID)
    if key not in self.watches:
      self.watches[key] = [] # create the initial list
    self.watches[key].append((id,callback,args))
    return id

  def _notifyWatcher(self, key, value):
    """run callbacks registered on an options key"""
    callbacks = self.watches.get(key, None)
    if callbacks:
      for item in callbacks:
        (id,callback,args) = item
        oldValue = self.get(key, None)
        if callback:
          callback(key,value,oldValue, *args)
        else:
          print "invalid watcher callback :", callback

  def get(self, key, default):
    try:
      return self.d.get(key, default)
    except Exception, e:
      print "options: exception while working with persistent dictionary:\n%s" % e
      return default

  def set(self, key, value):
    self.d[key] = value
    self.options.save()
    if key in self.watches.keys():
      self._notifyWatcher(key, value)

  def saveState(self):
    print "saving state"
    if self.activeManga: # is some manga actually loaded ?
      state = self.activeManga.getState()
      self.addToHistory(state)

  def _restoreState(self):
    openMangasHistory = self.getSortedHistory()
    if openMangasHistory:
      print "restoring last open manga"
      lastOpenMangaState = openMangasHistory[0]['state']
      self.openMangaFromState(lastOpenMangaState)
    else:
      print "no history found"

  def _resizeViewport(self,allocation):
    self.viewport = allocation

  def getFittingModes(self):
    """return list of fitting mode with key and description"""
    modes = [
            ("original", "fit to original size"),
            ("width", "fit to width"),
            ("height", "fit to height"),
            ("screen", "fit to screen")
            ]
    return modes

if __name__ == "__main__":
  mieru = Mieru()
