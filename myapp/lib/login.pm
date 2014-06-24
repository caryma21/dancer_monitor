package login;
use Dancer ':syntax';
use Net::SSH2;
use Data::Dumper;
$| = 1;
prefix '/monitor';
my $envMon = {
    NST => {
        '192.168.1.100' => [ 'user', 'passwd' ],
        '192.168.1.101' => [ 'user', 'passwd' ],
          '192.168.1.102' => [ 'user', 'passwd' ],
   },
    UAT => {
       '192.168.1.103' => [ 'user', 'passwd' ],
       '192.168.1.104' => [ 'user', 'passwd' ],
    }
   

};

sub monDisk {
    my ( $host, $user, $passwd, $env ) = @_;
    my @monArr;
    my $monOut;
    my $ssh2 = Net::SSH2->new();
    my $row;
    $ssh2->connect("$host") or die "$!";
    if ( $ssh2->auth_password( "$user", "$passwd" ) ) {
        my $chan = $ssh2->channel();

        #  $chan->blocking(1);
        $chan->shell();

        #monitor  memory useage
        # print $chan "svmon -G\n";
        #
        # while(<$chan>){
        #   if(/^memory\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)/){
        #  push @{$monOut->{'memory'}},sprintf"%0.2f",$2/$1*100;
        #    }
        #}
        #monitor  disk data
        print $chan "df -g\n";
        while (<$chan>) {
            if (/^\S+\s+([\d.]+)\s+([\d.]+)\s+(\d+)%\s+[^\/]+(\S+)$/) {

                # push @monArr, $3, $1, $2;
                if ( $3 > 80 ) {
                    push @{ $monOut->{'disk'} }, $4, $1, $2,
                        '<div class="jindu_r"><div style="width:'
                      . $3 . '%">'
                      . $3
                      . '%</div></div>';
                    ++$row;
                }

        #else{
        # push @{$monOut->{'disk'}},$4,$1,$2,
        # '<div class="jindu_g"><div style="width:'.$3.'%">'.$3.'%</div></div>';
        #}

            }
        }
        unless ( defined @{ $monOut->{'disk'} } ) {
            push @{ $monOut->{'disk'} }, 'normal', 'normal', 'normal', 'normal';
            $row = 1;
        }

        # monitor  cpu data
        print $chan "iostat\n";
        while (<$chan>) {
            if (/^\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+([\d.]+)/) {
                push @{ $monOut->{'cpu'} }, $1, $2, $3, $4;
            }
        }
        $monOut->{'ip'}  = $host;
        $monOut->{'env'} = $env;
        $monOut->{'row'} = $row;
    }
    $monOut;
}

#get '/stream'=>sub{
#    if(!session('user') && request->path_info !~m/^env/){
#        var requested_path=>request->path_info;
#        request->path_info('/monitor/login');
#
#    }
#    };
get '/login' => sub {

    template 'login' => { table => 'login' };

};

post '/login' => sub {
    if ( params->{username} eq 'test' && params->{password} eq 'test' ) {
        session user => params->{username};
        redirect params->{path};
    }
    else {
        redirect '/monitor/login';
    }
};

get '/logout' => sub {
    session->destroy;
    redirect '/monitor/login';
};

get '/:env' => sub {

    if ( session('user') ) {
        my $monitorOut;
        my $env = params->{env};
        $env = uc($env);

        #   for my $env (keys %$envMon){
        #  $monitorOut->{'env'}= $env;
        if ( defined $envMon->{$env} ) {
            for ( keys %{ $envMon->{$env} } ) {
                push @$monitorOut,
                  monDisk(
                    $_,
                    $envMon->{$env}->{$_}[0],
                    $envMon->{$env}->{$_}[1], $env
                  );
            }

            #}
            # return Dumper\$monitorOut;
            template 'monitor' => { table => $monitorOut };

            #template 'monitor' => {table => '2'};
        }
    }
        else {
            template 'monitor' => { table =>
'<a href="/monitor/login" style="color: #fff">Please Login!</a>'
            };
        }
    
};

get '/', sub {
    if ( session('user') ) {
        template 'monitor' => {};
    }
    else {
        template 'monitor' => { table =>
              '<a href="monitor/login" style="color: #fff">Please Login!</a>' };
    }
};

1;
