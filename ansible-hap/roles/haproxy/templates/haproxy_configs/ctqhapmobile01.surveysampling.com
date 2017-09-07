## File managed by ansible

### Look for place to define blacklist - currently in frontend ###
#	acl blockIPlist src -f /usr/local/haproxy/etc/blacklist.txt
#	http-request deny if blockIPlist
###

### Define qa-dkr1 frontend ### 
frontend qa-dkr1 *:80

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
	acl utest src 67.23.7.115
	
	## Host Header ACLs
	acl dkr1_host hdr(host) qa-dkr1.ssisurveys.com
	acl eve_host hdr(host) qa-eve.surveysampling.com
	acl gfk_host hdr(host) qa-gfk.surveysampling.com
	acl markettools_host hdr(host) qa-markettools.surveysampling.com
	
	# define static resources
	acl static_resources path_end .gif .css .css .js .png .jpg .bmp .tiff .ico

	## Path ACLs
	acl allowed_paths path_beg  /direct/ /DubPlanner/ /facebookService/ /FeasibilityExternal/ /Form/ /gsma/ /Intake/ /joinpagesvc/ /mas/ /partner/ /projects/ /public/ /rewardTV/ /rtr/ /scripts/ /Scripts/ /sfc/ /sfcws/ /SubStatusManager/ /web/ /favicon.ico /robots.txt    ### /mas is only in allowed_paths in prod, qa its under is_allowed_path and is_jboss7, /public does not exist in QA, scripts is also in is_preintake in qaproxy, sfc is also in is_clearconfigurationcache in QA

	acl direct path_beg /direct/    ###/direct does not exist in qa - will dispatch to default
	
	acl dkt path_beg /DubKnowledgeThreads/    ### does not exist in qa - will dispatch to default

	acl dubplanner path_beg /DubPlanner/    ###/DubPlanner exists in qa but only in allowed_paths ACL
	
	acl facebookservice path_beg /facebookService/    ###Exists in prod
	
	acl feas_block path_beg /FeasibilityExternal/views/feasibilityUI.xhtml    ###/FeasibilityExternal has no ACLs
	
	acl feas_external_views path_beg /FeasibilityExternal/views/marketTools.xhtml?guid=CF171FD7-BE6C-415E-976E-2B6905A5C3D5    ###/FeasibilityExternal has no ACLs
	
	acl form path_beg /Form    ###Exists in prod
	
	acl intake path_beg /Intake/    ### /Intake exists in prod but only with allowed_paths ACL, qaproxy has allowed_paths, is_post, is_postlead, is_tools
	
	acl joinpagesvc path_beg /joinpagesvc   ### Exists in prod in allowed_paths and joinpagesvc, qaproxy has is_allowed_path, is_joinpagesvc_postlead/is_joinpages
	
	acl projects path_beg /projects/    ### Exists in prod in allowed_paths, jboss7_external, projects, mvc_status, clearconfigurationcache, projects_start, path_block and in qaproxy its in is_allowed_path, is_webflow, is_jboss7
	acl projects_start path_beg /projects/start
	acl mvc_status path_beg /projects/mvc/status
	acl path_block path_beg /projects/edit
	
	acl sfcws path_beg /sfcws/    ### sfcws is in is_jboss7 as well for qaproxy

	acl clearconfigurationcache path_beg /projects/mvc/clearConfigurationCache /sfcws/cache/cacheConfiguration /partner/saas/cache/cacheConfiguration # Watch out for backend order of operations by projects ACL and sfcws ACL
	
	acl jboss7_external path_beg /projects/ /SubStatusManager/ /rtr/ /gsma/ /rewardTV/    ### /gsma exists in prod with allowed_paths and jboss7_external, in qa only part of is_jboss7, rtr is only in is_jboss7 in qaproxy

	acl web path_beg /web/
	acl privacypol path_beg /web/quickThoughts/privacyPolicy/en_US.html
	acl termsandcond path_beg /web/quickThoughts/termsAndConditions/en_US.html

	acl robots path_beg /robots.txt    ### does not exist in qaproxy, broken in prod
	
	acl rest path_beg /rest/    ### rewrite rule, everything else fails

	acl requiressl url_sub requireSSL=true

	acl internal_apps path_beg /feasibilityService/ /FeasibilityUI/ /costingService/ /DubKnowledge/ /ClaimCommunicationService/ /RewardCommunicationService/ /dynamixDashboard/ /DubKnowledgeContact/ /Dk/    #### I'm not going to worry about this in qa-dkr1


## Apply blocks
	http-request deny if path_block
	http-request deny if clearconfigurationcache !insideip
	http-request deny if mvc_status !insideip
	http-request deny if feas_external_views !marketip
	http-request deny if feas_block
	http-request deny unless allowed_paths or insideip or newrelicip or utest or rest

## Rewrite Rules
	reqrep ^(.*)/SubStatusManager(.*)  \1/SubStatusManager/SubStatusManagerServlet\2
	reqrep ^(.*)/SubStatusManager/SubStatusManagerServlet/status(.*)  \1/SubStatusManager/status\2
	reqrep ^(.*)/rest/v1/dkpmRestHandler.ashx(.*)	\1/mas/panelist/info\2

	rsprep ^(.*)http://dkr1.ssisurveys.com(.*) \1https://dkr1.ssisurveys.com\2

## Redirects
	redirect prefix https://dkr1.ssisurveys.com code 302 if projects_start requiressl

## Define errorfile - this is local to haproxy (replace with ns?)
	## errorfile 504 /usr/local/haproxy/etc/504.htm

## Define which backend based on ACL
	## use_backend ivproxy_newrelic if internal_apps    ## This is a prod only config - does not exist in qa
	## use_backend ctjbosss_newrelic if dkt newrelicip    ## DKT does not exist in qa
	use_backend ctwasd_form if form
	use_backend ctwasd_joinpagesvc if joinpagesvc
	## use_backend ctlan_dubplanner if dubplanner    ## No backend in qaproxy to handle the request
	use_backend ctwebmiscqa_web if web
	## use_backend ctqt_robots if robots    ## No backend in qaproxy to handle the request
	use_backend ctqdkre_static_resources if projects static_resources
	## use_backend ctpdkre_direct if direct    ## No backend in qaproxy to handle the request
	use_backend ctwasd_intake if intake
	default_backend ctqdkre_cluster

### End qa-dkr1 frontend ###

### Define Backends ###
## backend ivproxy_newrelic # why are we pinging against ivproxy vip?
##	# balancer config
##	option forwardfor
##
##	# node config
##	server ivproxy01 ivproxy01:80 check
##	server ututils01 ututils01:8888 backup
##
## backend ctjbosss_newrelic
##	# balancer config
##	option forwardfor
##	# node config
##	server ctjbosss01 ctjbosss01:8080 check
##	server ututils01 ututils01:8888 backup
##
backend ctwasd_form
	# balancer config
	balance roundrobin
	option forwardfor
	## reqrep ^(.*)/intake(.*) \1/joinpagesvc\2    ### In prod, not in qa
	## reqrep ^(.*)/Intake(.*) \1/joinpagesvc\2    ### In prod, not in qa
	# node config
	server ctwasd01 ctwasd01:8085 check
	server ututils01 ututils01:8888 backup

backend ctwasd_joinpagesvc
	# balancer config
	option forwardfor
	option httpclose  ## Not in prod
	reqrep ^(.*)/intake(.*)  \1/joinpagesvc\2    ## Not in prod
	reqrep ^(.*)/Intake(.*)  \1/joinpagesvc\2    ## Not in prod
	reqrep ^(.*)/fbapp_join(.*) \1/joinpagesvc\2    ## Not in prod
	rspadd Access-Control-Allow-Origin:\ *    ## Not in prod
	# node config
	server ctwasd01 ctwasd01:8084 check
	server ututils01 ututils01:8888 backup

backend ctwasd_intake
	# balancer config
	option forwardfor
	option httpclose  ## Not in prod
	reqrep ^(.*)/intake(.*)  \1/joinpagesvc\2    ## Not in prod
	reqrep ^(.*)/Intake(.*)  \1/joinpagesvc\2    ## Not in prod
	reqrep ^(.*)/fbapp_join(.*) \1/joinpagesvc\2    ## Not in prod
	rspadd Access-Control-Allow-Origin:\ *    ## Not in prod
	# node config
	server ctwasd01 ctwasd01:8084 check
	server ututils01 ututils01:8888 backup

## backend ctlan_dubplanner
##	# balancer config
##	balance roundrobin
##	# node config
##	server ctlan01 ctlan01:8080 check
##	server ctlan02 ctlan02:8080 check
##	server ututils01 ututils01:8888 backup
##
backend ctwebmiscqa_web
	# balancer config
	balance roundrobin
	option forwardfor
	option httpclose
	# node config
	server ctwebmiscqa01 ctwebmiscqa01:80 check
	server ututils01 ututils01:8888 backup

## backend ctqt_robots
##	# balancer config
##	option forwardfor
##	# node config
##	server ctqt01 10.4.2.154:80 check # server is being marked down - still needed?
##	server ututils01 ututils01:8888 backup
##
backend ctqdkre_static_resources
	# balancer config
	balance roundrobin
	option forwardfor
	option httpclose    ## Does not exist in prod
	option httpchk HEAD / HTTP/1.0
	option httpchk /projects/mvc/status
	cookie SERVERID insert indirect
	
	rspadd Cache-Control:\ max-age=604800
	rspdel ^Expires:(.*)
	rspdel ^Server:(.*)
	rspdel ^X-Powered-By:(.*)

	# node config
	server ctqdkre01 ctqdkre01:8080 cookie ctqdkre01 check weight 100
	server ctqdkre02 ctqdkre02:8080 cookie ctqdkre02 check weight 100
	server ututils01 ututils01:8888 backup

## backend ctpdkre_direct
##	# balancer config
##	balance roundrobin
##	cookie SERVERID insert indirect
##	option httpchk HEAD / HTTP/1.0
##	option httpchk /projects/mvc/status
##	option forwardfor except 10.4.1.0/24
##	reqrep ^(.*)/direct(.*)  \1/projects\2
##	rsprep ^(.*)/projects/eset(.*)  \1/direct/eset\2
##	# node config
##	server ctpdkre01 ctpdkre01:8080 cookie ctpdkre01 check weight 100
##	server ctpdkre02 ctpdkre02:8080 cookie ctpdkre02 check weight 100
##	server ctpdkre03 ctpdkre03:8080 cookie ctpdkre03 check weight 100
##	server ctpdkre04 ctpdkre04:8080 cookie ctpdkre04 check weight 100
##	server ctpdkre05 ctpdkre05:8080 cookie ctpdkre05 check weight 100
##	server ctpdkre06 ctpdkre06:8080 cookie ctpdkre06 check weight 100
##	server ututils01 ututils01:8888 backup
##
backend ctqdkre_cluster
	# balancer config
	balance roundrobin
	option forwardfor except 10.4.1.0/24
	option httpclose
	option httpchk HEAD / HTTP/1.0
	option httpchk /projects/mvc/status
	cookie SERVERID insert indirect
	rspdel ^Server:(.*)
	rspdel ^X-Powered-By:(.*)
	# rate limiting
	stick-table type ip size 200k expire 5m store gpc0,conn_cur,conn_cnt
	acl block_on_path path_beg -i /mas/login
	acl local_whitelist src -f /etc/haproxy/conf/whitelist.txt
	tcp-request content track-sc1 src if block_on_path METH_POST
	http-request tarpit if { src_conn_cnt ge 15 } block_on_path !local_whitelist
	# node config
	server ctqdkre01 ctqdkre01:8080 cookie ctqdkre01 check
	server ctqdkre02 ctqdkre02:8080 cookie ctqdkre02 check
	server ututils01 ututils01:8888 backup
