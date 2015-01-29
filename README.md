# nagios_jmeter_check

Fixed version of http://exchange.nagios.org/directory/Plugins/Java-Applications-and-Servers/jmeter-invocation-plugin-II/details.

jmeter.pl - Invokes a Java JMeter test plan.


 parameters:


   -j --jmeter: jmeter work directory (ex: /home/../jakarta-jmeter-2.3.2)  
   
   -p --plan: The JMeter .jmx test plan to run.  
              Must be located in current dir and there must also be a  
              properties file with the same name or the default -  
              jmeter.properties - will be used.  

   -t --timeout: The max time to allow this test plan to run. Killed if over  

   -w --warn: If the test plan runs longer than this many seconds return  
              WARNING  

   -c --critical: If the test plan runs longer than this many seconds,   
                  return CRITICAL  

   -h --host: Use to override request.host value in the properties file  

