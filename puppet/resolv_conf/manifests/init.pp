class resolv_conf {

    case $::operatingsystem {
        'CentOS', 'RedHat': {
            $supported = true
            $owner     = 'root'
            $group     = 'root'
            $mode      = '0644'
        }
        default: {
            #default case
        }
    } #End of case statement

    if ($supported == true)
    {
        if ($::hostname =~ /^foo/) or ($::hostname =~ /^bar/)
        {
            $ldapvip      = '99.99.99.99'
            $searchdomain = 'domain.local'

            file { '/etc/resolv.conf':
                ensure  => file,
                owner   => $owner,
                group   => $group,
                mode    => $mode,
                content => template('resolv_conf/resolv.conf.erb'),
            } #End file
        } #End if hostname
    } #End if supported
}

