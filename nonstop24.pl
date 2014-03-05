#!/usr/bin/perl
# UkrIndex LLC
# Yuriy Kolodovskyy
# +380 44 206 32 32 support
# +380 44 206 32 33 office
# +380 44 592 48 14 mobile
# +380 44 206 32 31 fax
# support@ukrindex.com
# http://www.ukrindex.com
#
# @version 20120428

use Digest::MD5 qw(md5_hex);
use Time::localtime;
use Time::Local;
use MIME::Base64;
use DBI;
use CGI;

$LOG_file='/usr/local/nodeny/module/nonstop24.log';

$cgi=new CGI;

$RESPONSE='';
$SECRET = 'SECRET';
$SERV_ID='SERVICEID';
$ACT=$cgi->param('ACT');
$PAY_AMOUNT=$cgi->param('PAY_AMOUNT');
$PAY_ACCOUNT=$cgi->param('PAY_ACCOUNT');
$PAY_ID=$cgi->param('PAY_ID');
$RECEIPT_NUM=$cgi->param('RECEIPT_NUM');
$TRADE_POINT=$cgi->param('TRADE_POINT');
$SERVICE_ID=$cgi->param('SERVICE_ID');
$SIGN=lc($cgi->param('SIGN'));

$DB_name = 'bill';
$DB_login = 'LOGIN';
$DB_pass = 'PASSWORD';

sub log
{
    my ($time);
    open LOG, ">>$LOG_file";
    $time = CORE::localtime;
    print LOG "$time: $_[0]\n";
    close LOG;
}

# connect to database
$mysql_connect_timeout||=8;
$DSN="DBI:mysql:database=$DB_name;host=localhost;mysql_connect_timeout=$mysql_connect_timeout";
unless ($dbh=DBI->connect($DSN,$DB_login,$DB_pass)) {
    &log("Connection to database failed");
    print "Content-type: text/html\n\n";
    print "Connection to database failed";
    exit;
}
$dbh->do("SET NAMES UTF8");

# load additional services
require '/usr/local/nodeny/nodeny.cfg.pl';
foreach $i (1..31) {
    if ($srvs{$i}=~/^(.+)-(.+)$/) {
        $srv_n[$i]=$1;
        $srv_p[$i]=$2;
    } else {
        $srv_n[$i]='';
        $srv_p[$i]=0;
    }
}

sub curr_time
{
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=CORE::localtime(time);
    return sprintf "%02d.%02d.%4d %02d:%02d:%02d",$mday,$mon+1,$year+1900,$hour,$min,$sec;
}

sub flush
{
    $RESPONSE='';
}

sub show
{
    print "Content-type: text/html\n\n";
    print "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    print " <pay-response>\n";
    print $RESPONSE;
    print " </pay-response>\n";
    exit;
}

sub add
{
    $RESPONSE.="  <$_[0]>$_[1]</$_[0]>\n";
}

sub add_transaction
{
    my($pay_id,$amount,$status,$time_stamp)=@_;
    $RESPONSE.="  <transaction>\n";
    $RESPONSE.="   <service_id>$SERV_ID</service_id>\n";
    $RESPONSE.="   <pay_id>$pay_id</pay_id>\n";
    $RESPONSE.="   <amount>$amount</amount>\n";
    $RESPONSE.="   <status>$status</status>\n";
    $RESPONSE.="   <time_stamp>$time_stamp</time_stamp>\n";
    $RESPONSE.="  </transaction>\n";
}

sub error
{
    my($status_code,$message)=@_;
    &log($message);
    &log("ACT:$ACT PAY_AMOUNT:$PAY_AMOUNT PAY_ACCOUNT:$PAY_ACCOUNT SERVICE_ID:$SERVICE_ID PAY_ID:$PAY_ID RECEIPT_NUM:$RECEIPT_NUM TRADE_POINT:$TRADE_POINT");
    &flush();
    &add('status_code', $status_code);
    &add('time_stamp', &curr_time());
    &show();
}

sub check_sign
{
    my($our_sign);
    $our_sign = md5_hex(join('_', $ACT, $PAY_ACCOUNT, $SERVICE_ID, $PAY_ID, $SECRET));
    &log("Local SIGN:$our_sign, Remote SIGN:$SIGN");
    &error(-101, 'Wrong SIGN') if ($SIGN ne $our_sign);
}

sub get_account
{
    my($id,$sth,$pm,$mid,$csum,$csum_c,$srvs_sum,$sr);
    
    $PAY_ACCOUNT=~/^(\d+)(\d)$/;
    $mid = $1;
    $csum = $2;
    
    $csum_c=0;
    $csum_c+=$_ foreach split //,$mid;
    $csum_c%=10;
    
    if ($csum ne $csum_c) {
	&error(-40, 'Wrong checksum');
    }
    
    $sth=$dbh->prepare("SELECT u.id as id, u.fio as fio, u.name as name,
				u.balance as balance, p.price as abonplata, u.srvs as srvs
			    FROM users u, plans2 p
			    WHERE u.paket=p.id AND u.id='$mid'");
    $sth->execute;
    
    &error(-40, 'Account not fount') unless ($pm=$sth->fetchrow_hashref);
    
    # services
    $srvs_sum = 0;
    $sr = $pm->{srvs};
    if (!($pm->{srvs} & 0x80000000)) {
        for ($i=1;$i<32;$i++,$sr>>=1) {
    	    next unless $srv_n[$i];
	    next if !($sr & 1);
	    $srvs_sum+=$srv_p[$i];
	}
    }
    
    my %user=();
    $user{mid} = $mid;
    $user{abonplata} = $pm->{abonplata};
    $user{name} = $pm->{fio};
    $user{account} = $PAY_ACCOUNT;
    $user{balance} = $pm->{balance} - $pm->{abonplata} - $srvs_sum;
    return %user;
}

sub has_pay
{
    $sth=$dbh->prepare("SELECT DATE_FORMAT(FROM_UNIXTIME(time), '%d.%m.%Y %H:%i:%s') as time_stamp, cash as amount
			FROM pays WHERE category=97 AND reason='$PAY_ID' LIMIT 1");
    $sth->execute;
    return $sth->fetchrow_hashref;
    
}

&error(-101, 'Wrong ACT number') unless ($ACT=~/^1|4|7$/);

# check user
if ($ACT eq '1') {
    &check_sign();

    &error(-101, 'Wrong account') unless ($PAY_ACCOUNT=~/^\d+$/);
    &error(-101, 'Pay ID not found') if (!$PAY_ID);
    &error(-101, 'Trade point not found') if (!$TRADE_POINT);
    
    %user=&get_account();
    &add('balance', $user{balance});
    &add('name', $user{name});
    &add('account', $user{account});
    &add('service_id', $SERV_ID);
    &add('abonplata', $user{abonplata});
    &add('min_amount', '0.01');
    &add('max_amount', '50000');
    &add('status_code', '21');
    &add('time_stamp', curr_time());
    &log("Show info about account $user{account}");
    &show();
}

# make pay
if ($ACT eq '4') {
    &check_sign();

    &error(-101, 'Wrong account') unless ($PAY_ACCOUNT=~/^\d+$/);
    &error(-101, 'Pay ID not found') if (!$PAY_ID);
    &error(-101, 'Trade point not found') if (!$TRADE_POINT);
    &error(-101, 'Receipt num not fount') if (!$RECEIPT_NUM);
    &error(-101, 'Wrong money format') unless ($PAY_AMOUNT=~/^\d+(\.\d{1,2}){0,1}$/);
    
    %user=&get_account();

    &error(-100, "Transaction $PAY_ID exist") if (&has_pay());
    
    $dbh->do("INSERT INTO pays SET 
		mid='$user{mid}',
		cash='$PAY_AMOUNT',
		time=UNIX_TIMESTAMP(NOW()),
		admin_id=0,
		admin_ip=0,
		office=0,
		bonus='y',
		reason='$PAY_ID',
		coment='NonStop24 ($RECEIPT_NUM)',
		type=10,
		category=97");
    $dbh->do("UPDATE users SET state='on', balance=balance+$PAY_AMOUNT WHERE id='$user{mid}'");
    $dbh->do("UPDATE users SET state='on' WHERE mid='$user{mid}'");

    &log("Pay added to billing PAY_ACCOUNT:$PAY_ACCOUNT SERVICE_ID:$SERVICE_ID PAY_ID:$PAY_ID TRADE_POINT:$TRADE_POINT RECEIPT_NUM:$RECEIPT_NUM PAY_AMOUNT:$PAY_AMOUNT");
    
    &add('service_id', $SERV_ID);
    &add('pay_id', $PAY_ID);
    &add('amount', $PAY_AMOUNT);
    &add('status_code', '22');
    $p=&has_pay();
    &add('time_stamp', $p->{time_stamp});
    &show();
}

# check pay
if ($ACT eq '7') {
    $PAY_ACCOUNT='';
    &check_sign();

    &error(-101, 'Pay ID not found') if (!$PAY_ID);
    if ($p=&has_pay()) {
	&add('status_code', '11');
	&add('time_stamp', &curr_time());
	&add_transaction($PAY_ID, $p->{amount}, '111', $p->{time_stamp});
	&show;
    } else {
	&error(-10, "Transaction $PAY_ID not found");
    }
}

&error(-101, "Wrong ACK $ACT");

