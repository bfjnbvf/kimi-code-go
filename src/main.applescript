-- Kimi Code Go
-- A lightweight macOS launcher for Kimi Code's web interface.
-- Starts (or reuses) a loopback-only local server, opens the browser,
-- and shuts everything down after the last browser connection is gone for ~60s.
--
-- Requirements: Kimi Code CLI installed (https://kimi.com/code)

use scripting additions

property defaultPort : "58627"
property serverPort : ""
property serverPID : ""
property startedServer : false
property shuttingDown : false
property kimiExecutable : ""
property serverToken : ""
property emptyConnectionCount : 0

on findKimi()
	set userHomeDirectory to do shell script "printf %s \"$HOME\""
	set candidates to {userHomeDirectory & "/.kimi-code/bin/kimi", userHomeDirectory & "/.kimi/bin/kimi", "/usr/local/bin/kimi", "/opt/homebrew/bin/kimi"}
	
	repeat with candidatePath in candidates
		try
			set checkResult to do shell script "test -x " & quoted form of (candidatePath as text) & " && echo found"
			if checkResult is "found" then return candidatePath as text
		end try
	end repeat
	
	return ""
end findKimi

on detectKimiPort()
	-- Find any running kimi web server and return its listening port.
	-- Returns "" if no kimi server is detected.
	try
		set commandText to "for pid in $(/usr/bin/pgrep -f 'kimi' 2>/dev/null); do " & ¬
			"/usr/sbin/lsof -nP -a -p $pid -iTCP -sTCP:LISTEN 2>/dev/null | " & ¬
			"/usr/bin/awk 'NR>1 && $1 ~ /kimi/ {split($9,a,\":\"); print a[length(a)]; exit}'; " & ¬
			"done | /usr/bin/head -n 1"
		set detectedPort to do shell script commandText
		if detectedPort is not "" then return detectedPort
	end try
	return ""
end detectKimiPort

on isKimiProcess(thePID)
	if thePID is "" then return false
	try
		set validatedPID to thePID as integer
		if validatedPID ≤ 0 then return false
	on error
		return false
	end try
	try
		set commandText to "/usr/sbin/lsof -a -p " & validatedPID & " -d txt -Fn 2>/dev/null | /usr/bin/grep -q kimi"
		do shell script commandText
		return true
	on error
		return false
	end try
end isKimiProcess

on listenerPIDForPort(thePort)
	set commandText to "/usr/sbin/lsof -nP -tiTCP:" & thePort & " -sTCP:LISTEN 2>/dev/null | /usr/bin/head -n 1 || true"
	return (do shell script commandText)
end listenerPIDForPort

on readServerToken()
	set userHomeDirectory to do shell script "printf %s \"$HOME\""
	set tokenPaths to {userHomeDirectory & "/.kimi-code/server.token", userHomeDirectory & "/.kimi/server.token"}
	repeat with tokenPath in tokenPaths
		try
			set tokenText to do shell script "test -r " & quoted form of (tokenPath as text) & " && /bin/cat " & quoted form of (tokenPath as text)
			if tokenText is not "" then return tokenText
		end try
	end repeat
	return ""
end readServerToken

on waitForServerToken()
	repeat 20 times
		set candidateToken to readServerToken()
		if candidateToken is not "" then return candidateToken
		delay 0.25
	end repeat
	return ""
end waitForServerToken

on connectionState()
	if serverToken is "" then return "unavailable"
	try
		set authHeader to "Authorization: Bearer " & serverToken
		set commandText to "/usr/bin/curl --fail --silent --show-error --max-time 5 --header " & quoted form of authHeader & " http://127.0.0.1:" & serverPort & "/api/v1/connections"
		set responseText to do shell script commandText
		set checkCommand to "/usr/bin/printf %s " & quoted form of responseText & " | /usr/bin/grep -Eq '\"connections\"[[:space:]]*:[[:space:]]*\\[[[:space:]]*\\]'"
		try
			do shell script checkCommand
			return "empty"
		on error
			return "active"
		end try
	on error
		-- Token may have been rotated; try re-reading once
		set freshToken to readServerToken()
		if freshToken is not "" and freshToken is not serverToken then
			set serverToken to freshToken
			try
				set authHeader to "Authorization: Bearer " & serverToken
				set commandText to "/usr/bin/curl --fail --silent --show-error --max-time 5 --header " & quoted form of authHeader & " http://127.0.0.1:" & serverPort & "/api/v1/connections"
				set responseText to do shell script commandText
				set checkCommand to "/usr/bin/printf %s " & quoted form of responseText & " | /usr/bin/grep -Eq '\"connections\"[[:space:]]*:[[:space:]]*\\[[[:space:]]*\\]'"
				try
					do shell script checkCommand
					return "empty"
				on error
					return "active"
				end try
			end try
		end if
		return "unavailable"
	end try
end connectionState

on openBrowser()
	try
		do shell script "/usr/bin/open http://127.0.0.1:" & serverPort & "/"
	end try
end openBrowser

on run
	set serverPID to ""
	set startedServer to false
	set shuttingDown to false
	set serverToken to ""
	set emptyConnectionCount to 0
	set serverPort to defaultPort
	
	-- Locate kimi binary
	set kimiExecutable to findKimi()
	if kimiExecutable is "" then
		display alert "Kimi Code Go 无法启动" message "未找到 kimi 命令行工具。请先安装 Kimi Code CLI。" as critical
		tell me to quit
		return
	end if
	
	-- Detect an already-running kimi web server (on any port)
	set detectedPort to detectKimiPort()
	if detectedPort is not "" then
		-- Found a running kimi server; take over monitoring
		set serverPort to detectedPort
		set serverPID to listenerPIDForPort(serverPort)
		set startedServer to true
		set serverToken to readServerToken()
		openBrowser()
	else
		-- No existing server; check if default port is occupied by something else
		set existingPID to listenerPIDForPort(defaultPort)
		if existingPID is not "" then
			-- Port occupied by non-kimi process
			display alert "Kimi Code Go 无法启动" message "端口 " & defaultPort & " 已被其他应用占用，且未检测到运行中的 Kimi Web 服务。请释放该端口后重试。" as critical
			tell me to quit
			return
		end if
		
		-- Start a new server on the default port
		try
			set commandText to quoted form of kimiExecutable & " web --host 127.0.0.1 --port " & defaultPort & " >/dev/null 2>&1 & echo $!"
			set serverPID to do shell script commandText
			if serverPID is not "" then
				set startedServer to true
				set serverToken to waitForServerToken()
				if serverToken is "" then display notification "服务已启动，但未找到本机服务令牌；关闭标签页后不会自动退出。" with title "Kimi Code Go"
			end if
		on error errorMessage
			display alert "Kimi Code Go 无法启动" message errorMessage as critical
			tell me to quit
		end try
	end if
end run

on idle
	if shuttingDown then return 1
	
	if startedServer and serverPID is not "" then
		try
			set commandText to "kill -0 " & serverPID & " 2>/dev/null"
			do shell script commandText
		on error
			set startedServer to false
			set serverPID to ""
			tell me to quit
			return 1
		end try
	end if
	
	if startedServer and serverToken is not "" then
		set currentConnectionState to connectionState()
		if currentConnectionState is "active" then
			set emptyConnectionCount to 0
		else if currentConnectionState is "empty" then
			set emptyConnectionCount to emptyConnectionCount + 1
			if emptyConnectionCount ≥ 2 then
				tell me to quit
				return 1
			end if
		else
			-- unavailable: transient failure, don't count
			set emptyConnectionCount to 0
		end if
	end if
	
	return 30
end idle

on quit
	set shuttingDown to true
	if startedServer and serverPID is not "" then
		try
			if isKimiProcess(serverPID) then
				do shell script "kill -TERM " & serverPID & " 2>/dev/null || true"
			end if
		end try
	end if
	set startedServer to false
	set serverPID to ""
	set serverToken to ""
	continue quit
end quit
