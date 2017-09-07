## File managed by ansible

### Look for place to define blacklist - currently in frontend ###
#	acl blockIPlist src -f /usr/local/haproxy/etc/blacklist.txt
#	http-request deny if blockIPlist
###

### Define dkr1 frontend ### 
frontend dkr1 *:80

## Define content to capture
	capture request header Referer len 100
	capture request header user-agent len 100
	capture response header Content-Length len 10
	capture response header Transfer-Encoding len 10
	capture response header location len 100
	capture cookie JSESS len 63
	capture cookie SESSION len 63

## Define ACLs
	## IP ACLs
	acl insideip src 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
	acl marketip src 72.5.112.0/24 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 			# Combine two ACLs??
	acl newrelicip src 50.31.164.139 50.18.57.7 50.112.95.211 54.247.188.179 54.248.250.232 54.251.34.67 177.71.245.207 184.73.237.85 204.93.223.151
	
	## Host Header ACLs
	acl dkr1_host hdr(host) dkr1.ssisurveys.com
	acl eve_host hdr(host) eve.surveysampling.com
	acl gfk_host hdr(host) gfk.surveysampling.com
	acl markettools_host hdr(host) markettools.surveysampling.com
	
	## Path ACLs
	acl allowed_paths path_beg  /direct/ /DubPlanner/ /facebookService/ /FeasibilityExternal/ /Form/ /gsma/ /Intake/ /joinpagesvc/ /mas/ /partner/ /projects/ /public/ /rewardTV/ /rtr/ /scripts/ /Scripts/ /sfc/ /sfcws/ /SubStatusManager/ /web/ /favicon.ico /robots.txt
	acl static_resources path_end .gif .css .css .js .png .jpg .bmp .tiff .ico
	acl sfcws path_beg /sfcws/
	acl intake path_beg /Intake/
	acl dubplanner path_beg /DubPlanner/
	acl web path_beg /web/
	acl robots path_beg /robots.txt
	acl jboss7_external path_beg /projects/ /SubStatusManager/ /rtr/ /gsma/ /rewardTV/
	acl direct path_beg /direct/
	acl projects path_beg /projects/
	acl mvc_status path_beg /projects/mvc/status
	acl clearconfigurationcache path_beg /projects/mvc/clearConfigurationCache /sfcws/cache/cacheConfiguration /partner/saas/cache/cacheConfiguration # Watch out for backend order of operations by projects ACL and sfcws ACL
	acl feas_block path_beg /FeasibilityExternal/views/feasibilityUI.xhtml
	acl form path_beg /Form
	acl joinpagesvc path_beg /joinpagesvc
	acl feas_external_views path_beg /FeasibilityExternal/views/marketTools.xhtml?guid=CF171FD7-BE6C-415E-976E-2B6905A5C3D5
	acl projects_start path_beg /projects/start
	acl requiressl url_sub requireSSL=true
	acl path_block path_beg /projects/edit
	acl privacypol path_beg /web/quickThoughts/privacyPolicy/en_US.html
	acl termsandcond path_beg /web/quickThoughts/termsAndConditions/en_US.html
	acl internal_apps path_beg /feasibilityService/ /FeasibilityUI/ /costingService/ /DubKnowledge/ /ClaimCommunicationService/ /RewardCommunicationService/ /dynamixDashboard/ /DubKnowledgeContact/ /Dk/
	acl dkt path_beg /DubKnowledgeThreads/
	acl facebookservice path_beg /facebookService/
	acl rest path_beg /rest/

## Apply blocks
	http-request deny if path_block
	http-request deny if clearconfigurationcache !insideip
	http-request deny if mvc_status !insideip
	http-request deny if feas_external_views !marketip
	http-request deny if feas_block
	http-request deny unless allowed_paths or insideip or newrelicip or rest

## Rewrite Rules
	reqrep ^(.*)/SubStatusManager(.*)  \1/SubStatusManager/SubStatusManagerServlet\2
	reqrep ^(.*)/SubStatusManager/SubStatusManagerServlet/status(.*)  \1/SubStatusManager/status\2
	reqrep ^(.*)/rest/v1/dkpmRestHandler.ashx(.*)	\1/mas/panelist/info\2
	rsprep ^(.*)http://dkr1.ssisurveys.com(.*) \1https://dkr1.ssisurveys.com\2

## Redirects
	redirect prefix https://dkr1.ssisurveys.com code 302 if projects_start requiressl

## Define errorfile - this is local to haproxy (replace with ns?)
##	errorfile 504 /usr/local/haproxy/etc/504.htm

## Define which backend based on ACL
	use_backend ivproxy_newrelic if internal_apps
	use_backend ctjbosss_newrelic if dkt newrelicip
	use_backend ctjoin_form if form
	use_backend ctwtools_joinpagesvc if joinpagesvc
	use_backend ctlan_dubplanner if dubplanner
	use_backend ctlan_web if web
	use_backend ctqt_robots if robots
	use_backend ctpdkre_static_resources if projects static_resources
	use_backend ctpdkre_direct if direct
	use_backend ctjoin_form if intake
	default_backend ctpdkre_cluster

### End qa-dkr1 frontend ###

### Define Backends ###
backend ivproxy_newrelic # why are we pinging against ivproxy vip?
	# balancer config
	option forwardfor

	# node config
	server ivproxy01 ivproxy01:80 check
	server ututils01 ututils01:8888 backup

backend ctjbosss_newrelic
	# balancer config
	option forwardfor
	# node config
	server ctjbosss01 ctjbosss01:8080 check
	server ututils01 ututils01:8888 backup

backend ctjoin_form
	# balancer config
	balance roundrobin
	option forwardfor
	reqrep ^(.*)/intake(.*) \1/joinpagesvc\2
	reqrep ^(.*)/Intake(.*) \1/joinpagesvc\2
	# node config
	server ctjoin01 ctjoin01:80 check
	server ctjoin02 ctjoin02:80	check
	server ctjoin03 ctjoin03:80 check
	server ctjoin04 ctjoin04:80 check
	server ctjoin05 ctjoin05:80 check
	server ututils01 ututils01:8888 backup

backend ctwtools_joinpagesvc
	# balancer config
	option forwardfor
	# node config
	server ctwtools01 10.4.1.39:8081 check
	server ututils01 ututils01:8888 backup

backend ctlan_dubplanner
	# balancer config
	balance roundrobin
	# node config
	server ctlan01 ctlan01:8080 check
	server ctlan02 ctlan02:8080 check
	server ututils01 ututils01:8888 backup

backend ctlan_web
	# balancer config
	balance roundrobin
	rspdel ^Expires:(.*)
	rspadd Cache-Control:\ max-age=604800
	# node config
	server ctlan01 ctlan01:80 check
	server ctlan02 ctlan02:80 check
	server ututils01 ututils01:8888 backup

backend ctqt_robots
	# balancer config
	option forwardfor
	# node config
	server ctqt01 10.4.2.154:80 check # server is being marked down - still needed?
	server ututils01 ututils01:8888 backup

backend ctpdkre_static_resources
	# balancer config
	balance roundrobin
	cookie SERVERID insert indirect
	option httpchk HEAD / HTTP/1.0
	option httpchk /projects/mvc/status
	rspdel ^Expires:(.*)
	rspdel ^Server:(.*)
	rspdel ^X-Powered-By:(.*)
	rspadd Cache-Control:\ max-age=604800
	# node config
	server ctpdkre01 ctpdkre01:8080 cookie ctpdkre01 check weight 100
	server ctpdkre02 ctpdkre02:8080 cookie ctpdkre02 check weight 100
	server ctpdkre03 ctpdkre03:8080 cookie ctpdkre03 check weight 100
	server ctpdkre04 ctpdkre04:8080 cookie ctpdkre04 check weight 100
	server ctpdkre05 ctpdkre05:8080 cookie ctpdkre05 check weight 100
	server ctpdkre06 ctpdkre06:8080 cookie ctpdkre06 check weight 100
	server ututils01 ututils01:8888 backup

backend ctpdkre_direct
	# balancer config
	balance roundrobin
	cookie SERVERID insert indirect
	option httpchk HEAD / HTTP/1.0
	option httpchk /projects/mvc/status
	option forwardfor except 10.4.1.0/24
	reqrep ^(.*)/direct(.*)  \1/projects\2
	rsprep ^(.*)/projects/eset(.*)  \1/direct/eset\2
	# node config
	server ctpdkre01 ctpdkre01:8080 cookie ctpdkre01 check weight 100
	server ctpdkre02 ctpdkre02:8080 cookie ctpdkre02 check weight 100
	server ctpdkre03 ctpdkre03:8080 cookie ctpdkre03 check weight 100
	server ctpdkre04 ctpdkre04:8080 cookie ctpdkre04 check weight 100
	server ctpdkre05 ctpdkre05:8080 cookie ctpdkre05 check weight 100
	server ctpdkre06 ctpdkre06:8080 cookie ctpdkre06 check weight 100
	server ututils01 ututils01:8888 backup

backend ctpdkre_cluster
	# balancer config
	balance roundrobin
	cookie SERVERID insert indirect
	option httpchk HEAD / HTTP/1.0
	option httpchk /projects/mvc/status
	option forwardfor except 10.4.1.0/24
	# rate limiting
	stick-table type ip size 200k expire 5m store gpc0,conn_cur,conn_cnt
	acl block_on_path path_beg -i /mas/login
	acl local_whitelist src -f /etc/haproxy/conf/whitelist.txt
	tcp-request content track-sc1 src if block_on_path METH_POST
	http-request tarpit if { src_conn_cnt ge 15 } block_on_path !local_whitelist
	# node config
	server ctpdkre01 ctpdkre01:8080 cookie ctpdkre01 check weight 100
	server ctpdkre02 ctpdkre02:8080 cookie ctpdkre02 check weight 100
	server ctpdkre03 ctpdkre03:8080 cookie ctpdkre03 check weight 100
	server ctpdkre04 ctpdkre04:8080 cookie ctpdkre04 check weight 100
	server ctpdkre05 ctpdkre05:8080 cookie ctpdkre05 check weight 100
	server ctpdkre06 ctpdkre06:8080 cookie ctpdkre06 check weight 100
	server ututils01 ututils01:8888 backup
