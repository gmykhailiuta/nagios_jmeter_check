#!/usr/bin/perl

#	Nagios JMeter plugin.

# Gennadiy Mykhailiuta gmykhailiuta@gmail.com
# Fixed performance data output
# Fixed JMeter results file to be stored in /tmp

#	Java and Web Services / University of Minnesota  info@jaws.umn.edu
#	Travis Noll tjn@umn.edu
#	Much thanks to Lizo for the heavy lifting.

#	This software is covered under the same licensing as Nagios itself and just
#	like Nagios is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
#	WARRANTY OF DESIGN, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE.
#
#	jmeter.pl - Invokes a Java JMeter test plan.
#
#	parameters:
#		-j --jmeter: jmeter work directory (ex: /home/../jakarta-jmeter-2.3.2)
#		-p --plan: The JMeter .jmx test plan to run. 
#		           Must be located in current dir and there must also be a 
#		           properties file with the same name or the default - 
#		           jmeter.properties - will be used.
#		-t --timeout: The max time to allow this test plan to run. Killed if over
#		-w --warn: If the test plan runs longer than this many seconds return
#		           WARNING
#		-c --critical: If the test plan runs longer than this many seconds, 
#		               return CRITICAL
#		-h --host: Use to override request.host value in the properties file
#
#	This process exits using the nagiosesque status:   
#		OK => 		0
#		WARNING => 	1
#		CRITICAL => 2
#		UNKNOWN => 	3*
#
#		* Unknown will signify something spooky happened- probably unrelated 
#		to server we are testing.
#
#
#	The output from the jmeter invocation is collected in
#	/tmp/[plan_name].[unix_time].[process_id].jtl  The output logged to that
#	file is then parsed by this script to gather statistics to be reported as
#	plugin performance data.
#
#

use strict;
use Carp;
use Getopt::Long;

#Paths to java and jmeter environment variables.
#$ENV{JAVA_HOME} = "/usr/java/jdk1.5.0_11/bin/java";

my %EXIT_STATUS = (
		"OK" => "0",
		"WARNING" => "1",
		"CRITICAL" => "2",
		"UNKNOWN" => 3,
);


my ($jmeter_directory, $plan, $timeout, $warnTime, $critTime);

Getopt::Long::Configure("no_ignore_case");
my $getoptret = GetOptions(
			"j|jmeter=s"		=> \$jmeter_directory,
			"p|plan=s"		=> \$plan,
			"t|timeout:s"		=> \$timeout,
			"w|warn:s"			=> \$warnTime,
			"c|critical:s"	=> \$critTime,
);

#default timeout.
$timeout ||= 30; 

#script begins with initial unknown state.
my $state = "UNKNOWN";  

#Identify where this script sits and use that as cwd.
my $path = substr($0,0, rindex ($0, "/"));
chdir $path;

#Look strip file extension from plan file for plan name.
my $planName = $plan;
$planName =~ s/\.jmx$//;

#Where to have jmeter create the plan results.
my $resultsFile = "/tmp/${\time()}.$$.jtl";

#Test for properly named properties file, otherwise use default.
my $propertiesFile = "$planName.properties";
if (! -e $propertiesFile) {
	$propertiesFile = $jmeter_directory."/bin/jmeter.properties";
}

#Our test plan.
my ($planFile) = "$plan";

#check plan File for existence.
if (!-f $planFile){
	my $state = 'CRITICAL';
	print STDERR "$state: no test plan $planFile\n" and exit($EXIT_STATUS{$state});
}


#Build the invocation
#my $cmd = $ENV{JAVA_HOME};
my $cmd = "java -server ".
				# Replace the following link for this one if you are using a proxy
				#"-jar $jmeter_directory/bin/ApacheJMeter.jar -H id_address -P port". 
				" -jar $jmeter_directory/bin/ApacheJMeter.jar".
				" --nongui".
				" --propfile $propertiesFile".
				" --testfile $planFile".
#				" --homedir $jmeter_directory/bin".
				" --logfile $resultsFile";

use IPC::Open3;
local (*HIS_IN, *HIS_OUT, *HIS_ERR);

#Uncomment it to show jmeter call. Could be usefull for debugging
#print "\n\n $cmd\n\n";


# Invoke the java/jmeter process.
my $childpid = open3(*HIS_IN, *HIS_OUT, *HIS_ERR, $cmd);

# We will only run for so long.  Handle an alarm signal as a reason to kill the
# spawned child process and exit.
$SIG{'ALRM'} = sub {
	print ("CRITICAL: Timeout $timeout expired.\n");
	if ($childpid) {
		kill 1, $childpid;
	}
	exit $EXIT_STATUS{"CRITICAL"};
};
alarm($timeout);
my ($startTime) = time();

close HIS_IN;  ### sends eof to child
my @errs = <HIS_ERR>;
close HIS_OUT;
close HIS_ERR;

# When we close HIS_ERR $? becomes the status.
if ($? || @errs) {
	$state = "CRITICAL";
	print "$state: '$cmd' exit with wait status of $?";
	print "\t Errors ".join("\n",@errs) if (@errs);
	print "\n";
	exit($EXIT_STATUS{$state});
}
my ($endTime) = time;



#  Open the result file and sum up the individual page times
my $sum = 0;
my $suminsecs = 0;

unless (open FILE, $resultsFile) {
	$state = "CRITICAL";
	print "$state: Can't open $resultsFile: $!\n";
	exit($EXIT_STATUS{$state});
}

my ($failure) = "";

while (my $line = <FILE>) {
	my @tokens = split /,|\n/, $line;
	$sum += $tokens[1];
	if ($tokens[7] eq 'false') {
		$failure .= "Failed to load page: $tokens[2].   ";
	}
}

close FILE;

#comment this line out if you want to retain the results file for 
#debugging/detailed results.
unlink ($resultsFile);

if ($sum > 0) {
  $suminsecs = $sum / 1000;
}


if ($failure) {
	$state = "CRITICAL";
	print "$state:$failure\n";
} else {
	my $details = '';

	if (defined($critTime) && ($critTime < $suminsecs)) {
		$state = "CRITICAL";
		$details = " (critical $critTime)";
	}elsif (defined($warnTime) && ($warnTime < $suminsecs)) {
		$state = "WARNING";
		$details = " (warning $warnTime)";
	} else {
		$state = "OK";
	}

	print "$state : $details | sum_time=$suminsecs\n";

}
exit ($EXIT_STATUS{$state});
