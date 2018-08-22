class splunkuniversalforwarder{
    #Set Dynamic vars
    $build = '6.4.2-00f5bb3fa822'
    
    #Set static vars
    $repo          = 'http://ctpkgserve01:8090'
    $owner         = 'root'
    $group         = 'root'
    $mode          = '0644'
    $splunkhome    = '/opt/splunkforwarder'
    $splunkbin     = 'bin/splunk'
    $phonehome     = '600'                                 #Used in template
    $deployserver  = 'ctsplunkd01.surveysampling.com:8089' #Used in template
    
    case $::architecture {
        'x86_64': {
            $splunkversion = "splunkforwarder-${build}-linux-2.6-x86_64.rpm"
        }
        'i386': {
            $splunkversion = "splunkforwarder-${build}.i386.rpm"
        }
        default: {
            #default case
        }
    } #End of case statement
    
    case $::operatingsystem {
        'CentOS', 'RedHat': {
            $supported = true
        } #End supported OS
        default: {
            #default case
        } #End default case
    } #End of case statement
    
    if ($supported == true)
    {
        package { 'splunkforwarder':
            provider => 'rpm',
            ensure   => "${build}",
            source   => "${repo}/${splunkversion}",
        } #End package

        exec { 'enablesplunk':
            command     => "${splunkhome}/${splunkbin} start --accept-license --no-prompt --answer-yes",
            path        => '/usr/local/bin:/bin:/usr/bin:/usr/sbin:/sbin',
            onlyif      => "test `ps aux | grep splunk | grep -v grep | wc -l` -eq 0",
        } #End exec

        service { 'splunk':
            ensure    => running,
            enable    => true,
            require => Exec['enablesplunk'],
        } #End service

        file { "${splunkhome}/etc/system/local/deploymentclient.conf":
            ensure  => file,
            owner   => $owner,
            group   => $group,
            mode    => $mode,
            content => template('splunkuniversalforwarder/deployment.conf.erb'),
        } #End file
    } #End if
} #End class
