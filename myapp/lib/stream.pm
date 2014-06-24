package batch;
use Dancer ':syntax';
use utf8;
use Dancer::Plugin::Database;
use Data::Dumper;
use DBD::Oracle;

get '/stream', sub {
    
    my $onl_capture_status = "
     select STATUS from dba_capture
     ";
    my $onl_streams_capture = "
     select STATE from gv\$streams_capture
     ";
    my $onl_propagation_status = "
     select STATUS from dba_propagation
     ";
    my $bak_time_diff = "select
     s.status,
to_char(T.applied_message_create_time,'yyyy-mm-dd hh24:mi:ss'),
to_char(T.apply_time ,'yyyy-mm-dd hh24:mi:ss') ,
round((to_number(t.APPLY_TIME - t.APPLIED_MESSAGE_CREATE_TIME))*24*60*60) diff
from dba_apply S, dba_apply_progress T where s.apply_name=t.apply_name";
    my $bak_stream_error = "
     select count(*) from dba_apply_error
     ";

    # my  $bak_stream_queue="
    #   select  count (*) from strmadmin.streams_queue_table";
    my @mytable;
    my $env;

    #loop  stream env
    for $env (qw/UAT NUAT NST NSHT MEMBER/) {

        #for $env (qw/UAT NUAT/) {
        my @tmptable;
        
        my $dbh = database($env);
  
        #create stream  status table;
        my $sth = $dbh->prepare("$onl_capture_status");
        $sth->execute();
        push @tmptable, [ $env, $sth->fetchrow_array ];
        $sth = $dbh->prepare("$onl_propagation_status");
        $sth->execute();
        push @tmptable, $sth->fetchrow_arrayref;
        $sth = $dbh->prepare("$onl_streams_capture");
        $sth->execute();
        my $row_capture = $sth->fetchrow_arrayref;
        $row_capture->[0]
          ? push @tmptable, [ $row_capture->[0] ]
          : push @tmptable, ['Unknow'];

        $dbh = database("${env}BKP");
  
        $sth = $dbh->prepare("$bak_time_diff");

        $sth->execute();
        my $row = $sth->fetchrow_arrayref;

        push @tmptable, $row;

        $sth = $dbh->prepare("$bak_stream_error");
        $sth->execute();

        if ( defined $row->[3] and $row->[3] =~ /^\d+$/ ) {
            $row->[3] <= 300 ? push @tmptable, ['同步'] : push @tmptable,
              ['不同步'];
        }
        push @tmptable, $sth->fetchrow_arrayref;

        for my $tmp (@tmptable) {
            for (@$tmp) {
                if (   defined $row->[3]
                    && $row->[3] =~ /^\d+$/
                    && $row->[3] <= 300
                    && defined $row_capture->[0] )
                {
                    push @mytable, "<font id='status_success' >$_</font>";
                }
                else {
                    push @mytable, "<font id='status_fail' >$_</font>";
                }
            }
        }

        #  $mytable[-1] .= "</tr>";
        $sth->finish;
        $dbh->disconnect;

    }
    template 'stream' => { table => \@mytable };

    #return Dumper\@mytable;
         
};

true;
