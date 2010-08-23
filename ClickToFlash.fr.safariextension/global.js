var CTF_instance = 0; // incremented by one whenever a ClickToFlash instance with content is created
const killers = [new YouTubeKiller(), new VimeoKiller(), new DailymotionKiller(), new VeohKiller(), new JWKiller()];

// EVENT LISTENERS
safari.application.addEventListener("message", respondToMessage, false);
safari.application.addEventListener("contextmenu", handleContextMenu, false);
safari.application.addEventListener("command", doCommand, false);
safari.extension.settings.addEventListener("change", handleChangeOfSettings, false);

function respondToMessage(event) {
    switch (event.name) {
        case "canLoad":
            event.message = respondToCanLoad(event.message);
            break;
        case "killFlash":
            killFlash(event.message);
            break;
    }
}

function respondToCanLoad(message) {
    switch(message) {
        case "sIFR":
            if (safari.extension.settings["sifrReplacement"] == "textonly") {
                return {"canLoad": false, "debug": safari.extension.settings["debug"]};
            } else return {"canLoad": true};
        case "getInstance":
            return ++CTF_instance;
        case "getSettings":
            return getSettings();
    }
}

function printMedia(mediaType) {
    switch(mediaType) {
        case "video": return "Video";
        case "audio": return "Audio";
        default: return "Video";
    }
}

function handleContextMenu(event) {
    if(!event.userInfo.CTFInstance) {
        if(safari.extension.settings["useLAcontext"] && event.userInfo.blocked > 0) event.contextMenu.appendContextMenuItem("loadall", "D�bloquer Flash sur cette page (" + event.userInfo.blocked + ")");
        if(safari.extension.settings["useWLcontext"]) {
            event.contextMenu.appendContextMenuItem("locwhitelist", "Ajouter � la liste blanche\u2026");
        }
        return;
    }
    if(event.userInfo.isH264) {
        event.contextMenu.appendContextMenuItem(event.userInfo.CTFInstance + "," + event.userInfo.elementID + ",reloadFlash", "Relancer avec Flash");
		if(safari.extension.settings["useQTcontext"]) event.contextMenu.appendContextMenuItem(event.userInfo.CTFInstance + "," + event.userInfo.elementID + ",qtp", "Ouvrir dans QuickTime Player");
		if(event.userInfo.siteInfo && safari.extension.settings["useVScontext"]) event.contextMenu.appendContextMenuItem("gotosite", "Voir la vid�o sur " + event.userInfo.siteInfo.name);
    } else {
        if(event.userInfo.hasH264) {
			event.contextMenu.appendContextMenuItem(event.userInfo.CTFInstance + "," + event.userInfo.elementID + ",flash", "Lancer Flash");
			event.contextMenu.appendContextMenuItem(event.userInfo.CTFInstance + "," + event.userInfo.elementID + ",remove", "Supprimer Flash");
			if(safari.extension.settings["useQTcontext"]) event.contextMenu.appendContextMenuItem(event.userInfo.CTFInstance + "," + event.userInfo.elementID + ",qtp", "Ouvrir dans QuickTime Player");
			if(event.userInfo.siteInfo && safari.extension.settings["useVScontext"]) event.contextMenu.appendContextMenuItem("gotosite", "Voir la vid�o sur " + event.userInfo.siteInfo.name);
        } else {
			event.contextMenu.appendContextMenuItem(event.userInfo.CTFInstance + "," + event.userInfo.elementID + ",remove", "Supprimer Flash");
		}
        if(safari.extension.settings["useWLcontext"]) {
            event.contextMenu.appendContextMenuItem("srcwhitelist", "Ajouter � la liste blanche\u2026");
        }
        // BEGIN DEBUG
        if(safari.extension.settings["debug"]) {
            event.contextMenu.appendContextMenuItem(event.userInfo.CTFInstance + "," + event.userInfo.elementID + ",show", "Voir l'�l�ment " + event.userInfo.CTFInstance + "." + event.userInfo.elementID);
        }
        //END DEBUG
    }
}

function doCommand(event) {
	switch(event.command) {
		case "gotosite":
			var newTab = safari.application.activeBrowserWindow.openTab("foreground");
	        newTab.url = event.userInfo.siteInfo.url;
			break;
		case "locwhitelist":
			handleWhitelisting(true, event.userInfo.location);
			break;
		case "srcwhitelist":
			handleWhitelisting(false, event.userInfo.src);
			break;
		case "loadall":
			safari.application.activeBrowserWindow.activeTab.page.dispatchMessage("loadAll", "");
			break;
		default:
			safari.application.activeBrowserWindow.activeTab.page.dispatchMessage("loadContent", event.command);
			break;
	}
}

function handleWhitelisting (type, url) {
    var newWLstring = prompt("Autoriser " + (type ? "Flash si l'adresse de la page contient" : "les �l�ments Flash provenant de"), url);
    if(newWLstring) {
        safari.extension.settings["use" + (type ? "loc" : "src") + "Whitelist"] = true;
        if(type && safari.extension.settings["locwhitelist"] == "www.example.com, www.example2.com") { // get rid of the example
            safari.extension.settings[(type ? "loc" : "src") + "whitelist"] = newWLstring;
        } else {
            var comma = safari.extension.settings[(type ? "loc" : "src") + "whitelist"].replace(/\s+/,"") ? ", " : "";
            safari.extension.settings[(type ? "loc" : "src") + "whitelist"] += comma + newWLstring;
        }
    }
}

function handleChangeOfSettings(event) {
    if(event.key == "volume") {
        // send to all pages or just the active one??
        safari.application.activeBrowserWindow.activeTab.page.dispatchMessage("updateVolume", event.newValue);
    } else if(event.key = "opacity") {
		dispatchMessageToAllPages("updateOpacity", event.newValue);
	}
}

function getSettings() {
	var settings = new Object();
	settings.useH264 = safari.extension.settings["useH264"];
	settings.usePlaylists = safari.extension.settings["usePlaylists"];
	//settings.maxres = safari.extension.settings["maxresolution"];
    settings.H264autoload = safari.extension.settings["H264autoload"];
    settings.H264behavior = safari.extension.settings["H264behavior"];
    settings.volume = safari.extension.settings["volume"];
    if(safari.extension.settings["uselocWhitelist"]) {
        settings.locwhitelist = safari.extension.settings["locwhitelist"].replace(/\s+/g,"");
        settings.locblacklist = safari.extension.settings["locblacklist"].replace(/\s+/g,"");
        settings.locwhitelist = (settings.locwhitelist ? settings.locwhitelist.split(/,(?![^\(]*\))/) : null);
        settings.locblacklist = (settings.locblacklist ? settings.locblacklist.split(/,(?![^\(]*\))/) : null);
    }
    if(safari.extension.settings["usesrcWhitelist"]) {
        settings.srcwhitelist = safari.extension.settings["srcwhitelist"].replace(/\s+/g,"");
        settings.srcblacklist = safari.extension.settings["srcblacklist"].replace(/\s+/g,"");
        settings.srcwhitelist = (settings.srcwhitelist ? settings.srcwhitelist.split(/,(?![^\(]*\))/) : null);
        settings.srcblacklist = (settings.srcblacklist ? settings.srcblacklist.split(/,(?![^\(]*\))/) : null);
    }
    settings.loadInvisible = safari.extension.settings["loadInvisible"];
    if(settings.loadInvisible) settings.maxinvdim = safari.extension.settings["maxinvdim"];
    settings.sifrReplacement = safari.extension.settings["sifrReplacement"];
	settings.opacity = safari.extension.settings["opacity"];
    settings.debug = safari.extension.settings["debug"];
	return settings;
}

function killFlash(data) {
    var killerID = findKillerFor(data);
    if(killerID == null) return; // this flash element can't be killed :(
    // BEGIN DEBUG
    if(safari.extension.settings["debug"]) {
        if(!confirm("Killer '" + killers[killerID].name + "' thinks it might be able to process target " + data.CTFInstance +"."+ data.elementID + ".")) return;
    }
    // END DEBUG
    var callback = function(videoData) {
        videoData.elementID = data.elementID;
        videoData.CTFInstance = data.CTFInstance;
        // the following messsage must be dispatched to all pages to make sure that
        // pages or tabs loading in the background get their videoData
        dispatchMessageToAllPages("mediaData", videoData);
    };
    killers[killerID].processElement(data, callback);
}

function findKillerFor(data) {
	for (i = 0; i < killers.length; i++) {
        if(killers[i].canKill(data)) return i;
    }
    return null;
}

function dispatchMessageToAllPages(name, message) {
    for(var i = 0; i < safari.application.browserWindows.length; i++) {
        for(var j = 0; j < safari.application.browserWindows[i].tabs.length; j++) {
            // must be careful here since tabs such as Bookmarks or Top Sites do not have the .page proxy
            if(safari.application.browserWindows[i].tabs[j].page) {
                safari.application.browserWindows[i].tabs[j].page.dispatchMessage(name, message);
            }
        }
    }
}

