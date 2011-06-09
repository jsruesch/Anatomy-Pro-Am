config = require '../config'
fbhelper = require '../fbhelper'

## dependencies
DNode = require 'dnode@0.6.10'
_ = require('underscore@1.1.5')._
Backbone = require 'backbone@0.3.3'
resources  = require '../models/resources'

util = require './util'

store = new util.MemoryStore
sessionManager = new util.SessionManager
activityManager = new util.ActivityManager
flush = util.flushDatabase

## DNode RPC API
exports.createServer = (app) ->
	client = DNode (client, conn) ->
		@login = (pw, emit) ->
			if pw is 'tumor'
				emit.apply emit, ['Continue']
			if pw is 'AdminPanel33!'
				emit.apply emit, ['AdminPanel']
		@subscribe = (auth_token, emit) ->
			session = sessionManager.sessionConnected auth_token, conn, client, emit
			emit.apply emit, ['myINFO', session.fbUser, session.player_color]
			sessionManager.publish 'FriendCameOnline', session.fbUser
		conn.on 'end', ->
			session = sessionManager.sessionDisconnected conn
			sessionManager.publish 'FriendWentOffline', session.fbUser
		@sendJoinRequest = (fn, id, player_id, player_name, player_avatar) ->
			sessionManager.sendJoinRequest fn, id, player_id, player_name, player_avatar
		@newCase = (case_number, thisPlayer, emit) ->
			returnedValue = activityManager.newActivity case_number, thisPlayer
			sessionManager.setActivity thisPlayer, returnedValue
			emit.apply emit, ['setCurrentCase', returnedValue]
			sessionManager.publish 'PlayerStartedCase', thisPlayer, returnedValue
		@getCase = (activity_id) ->
			return activityManager.getActivity(activity_id)
		@pointColored = (activity_id, player_id, points) ->
			for point in points
				activityManager.current[activity_id].createPoint player_id, point
			sessionManager.publish 'pointColored', player_id, points
		@pointErased = (activity_id, player_id, points) ->
			for point in points
				activityManager.current[activity_id].deletePoint player_id, point
			sessionManager.publish 'pointErased', player_id, points
		@clearCanvas = (activity_id, player_id, layer) ->
			activityManager.current[activity_id].clearCanvas player_id, layer
			sessionManager.publish 'canvasCleared', player_id, layer
		@getColoredPointsForThisLayerAndPlayer = (activity_id, requester_id, player, layer, emit) ->
			activityManager.current[activity_id].getPointsForPlayer layer, player, (points) ->
				emit.apply emit, ['setColoredPointsForThisLayer', {player: player, payload: points} ]
		@done = (player) -> 
			console.log player
			activityManager.current[player.current_case_id].playerDone player, (result)  ->
				if result == true
					sessionManager.publish 'everyoneIsDone', player.current_case_id
		@notDone = (player) ->
			activityManager.current[player.current_case_id].playerNotDone player
			sessionManager.publish 'playerNotDone', player.current_case_id
		@joinActivity = (activity_id, player) ->
			activityManager.current[activity_id].addPlayer(player)
			sessionManager.setActivity player, activity_id
			sessionManager.publish 'PlayerStartedCase', player, activity_id
		@sendChat = (activity_id, player_id, message) ->
			activityManager.current[activity_id].addChatMessage player_id, message
			sessionManager.publish 'newChat', player_id, message
		@getChatHistoryForActivity = (activity_id, emit) ->
			activityManager.current[activity_id].getChatHistoryForActivity (chats) ->
				emit.apply emit, ['setChatHistory', {payload: chats}]
		@getOnlineFriends = (uid, emit) ->
			fbhelper.getOnlineFriends uid, (cb) ->
				emit.apply emit, ['setAllFriends', {payload:cb}]
		@appRequest = (myid, yourid) ->
			fbhelper.appRequest myid, yourid
		@cursorPosition = (activity_id, player, layer, position) ->
			sessionManager.publish 'newCursorPosition', player, layer, position
		@getColor = (activity_id, player_id, emit) ->
			activityManager.current[activity_id].getColor player_id, (color) ->
				console.log color
				sessionManager.sessions_for_facebook_id[player_id].fbUser.player_color = color
				emit.apply emit, ['setColor', {payload:color}]
		@leftActivity = (activity_id, player) ->
			activityManager.current[activity_id].removePlayer(player.id);
			sessionManager.setActivity player, 0
			sessionManager.publish 'playerLeft', player
			
		# dnode/coffeescript fix:
		@version = config.version
	.listen {
        protocol : 'socket.io',
        server : app,
        transports : 'websocket flashsocket xhr-polling '.split(/\s+/),
	}

# creates a new session with the facebook_id and returns a token
exports.setFbUserAndGetToken = (fbUser) ->
	if fbUser
		return sessionManager.createSession fbUser

exports.sessionManager = sessionManager
