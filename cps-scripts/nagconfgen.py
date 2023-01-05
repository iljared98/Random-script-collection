# Created by: I. Jared 11/28/2022
# This script is designed to reduce the tedium from generating 
# Nagios host configs. Since Nagios Core does not come with a config wizard
# or any kind of OFFICIAL GUI etc., this is the best that is available 
# for our use case. GUIs for this type of setup exist, however, they are usually not distro 
# agnostic and break frequently; this should work with future updates. The script primarily 
# works by feeding user inputs from a loop into a string that is eventually 
# written to a blank config file and moved to where it needs to go, based on 
# input. 

# If a config for a host already exists or if the host isn't pingable by the script, a config will not be written.
# Configs that are generated will need to be checked with the Nagios validation command, found under
# our 'nagvalidate' alias in the Knowledge Base. The Nagios service will also need to be reloaded afterwards
# using the 'nagreload' alias which is found in the same article as the previous alias.
# The script will output all inserted values to ensure there aren't any errors put into the config before
# generating the file.

# 1/4/2023 revision; added ping check function. Added additional exit prompts. 
# Updated script comments/documentation.

import os
import sys
from datetime import datetime

# Basic function to check if the host being added is alive. If the host isn't pingable,
# this will prevent it from being added.
def checkIPforHost(IPAddress, serverOS):
    if "win32" not in serverOS: # for Linux
        response = os.system(f"ping -c 1 {IPAddress}")
        if response == 0:
            print(f"\nResponse for {IPAddress} was successful, proceeding to generate config...")
            return True
        else:
            print(f"\nResponse for {IPAddress} has failed, aborting config generation...")
            return False
    else:
        response = os.system(f"ping -n 1 {IPAddress}")
        if response == 0:
            print(f"\nResponse for {IPAddress} was successful, proceeding to generate config...")
            return True
        else:
            print(f"\nResponse for {IPAddress} has failed, aborting config generation...")
            return False

def main():
    # Keep the program in a loop so configs can keep being generated until the task is killed/exited via a prompt.
    while True:
        # Terminal clutter removal
        userOS = str(sys.platform)
        if "win32" not in userOS:
            os.system('clear')
        else:
            os.system('cls') # only needed for testing the script on Windows workstations.
		
            
        print("***** NAGIOS CONFIG GENERATOR *****\n*****                         *****\n\nWhat type of host config is being generated?\n1 - Network Switch\n2 - Windows\n3 - Generic Server\n4 - Printer\n5 - Exit Program")
        while True:
            confSelect = input("\n\nInput: ")
            if confSelect.lower() not in ('1', '2', '3', '4', '5'):
                print("\nNot a valid input, please select a config type:\n\n1 - Network Switch\n2 - Windows Server\n3 - Generic Server\n4 - Printer\n5 - Exit Program\n\nInput: ")
            else:
                break
        
        if confSelect == "1":
            while True:
                print("\nYou have selected: Network Switch")
                HOSTNAME = input("\nPlease enter the hostname of the switch (i.e. JH_EX1_MDF_XXXX): ")
                HOST_ALIAS = input("\nPlease enter the host alias of the switch (i.e. JH SW1 Band Room): ")
                IP_ADDR = input("\nPlease enter the IP address of the switch (i.e. 172.16.2.38): ")
                
                while True:
                    SWITCH_SITE = input("\nWhich site does this switch belong to?\nCE\nNW\nSS\nMIGC\nHIGC\nJH\nIHS\nHS\nESC\n\nInput: ")
                    if SWITCH_SITE.upper() not in ('CE', 'NW', 'SS', 'MIGC', 'HIGC', 'JH', 'IHS', 'HS', 'ESC'): # Messy, needs a more elegant solution, especially for the host-groups plan.
                        print("\nSite not valid, please enter a valid site.")
                    else:
                        break

                correctVals = input(f"\n\nDo these values look correct (Y / N)?\nHostname: {HOSTNAME}\nAlias: {HOST_ALIAS}\nIP Address: {IP_ADDR}\nSite Location: {SWITCH_SITE.upper()}\n\nInput: ")
                if correctVals.lower() == "y": 
                    break
                else:
                    continue
            
            # Adding this so we have timestamps on all generated configs. Helps keep track of anomalies / issues. NOTE: Older configs may be using
			# UTC time instead of CST. You will need to ensure that the Linux system this is on will be using the 'America/Chicago'  timezone.
			# America/Chicago was set on CPS-Nagios in late October-early November 2022.
            today = datetime.now()
                
            # Do not touch unless Nagios changes how formatting works for configs, or if you're adding another service for Nagios to check.
			# For other service checks, these must be defined in the host's respective original template (found in the /objects folder).
            confFileString = (
                f"# CONFIG GENERATED ON : {today.strftime('%m-%d-%Y %I:%M %p')}\n# BY NAGIOS CONFIG GENERATOR\n\n"
                "define host {\n"
                "\tuse                     generic-switch\n"
                f"\thost_name               {HOSTNAME}\n"
                f"\talias                   {HOST_ALIAS}\n"
                f"\taddress                 {IP_ADDR}\n"
                f"\thostgroups              {SWITCH_SITE.upper()}-switches\n"
                "\tcontact_groups          cps-network-alerts\n"
                "}\n\n"
                "define service {\n"
                "\tuse                     generic-service\n"
                f"\thost_name               {HOSTNAME}\n"
                "\tservice_description     PING\n"
                "\tcheck_command           check_ping!200.0,20%!600.0,60%\n"
                "\tcheck_interval          5\n"
                "\tretry_interval          1\n"
                "}\n\n")
            
            SWITCH_DIR = f"/usr/local/nagios/etc/switches/{SWITCH_SITE.upper()}/{HOSTNAME}.cfg"
            if os.path.exists(SWITCH_DIR):
                print("\nERROR: The host you are trying to create already exists.\n")
            else:
                if checkIPforHost(IP_ADDR, userOS) == True:
                    with open(SWITCH_DIR, "w") as cfgFile:
                    	cfgFile.write(confFileString)
                    	print(f"\n{SWITCH_DIR} config file has been successfully written.\n")
                    #with open(f"{HOSTNAME}.cfg", "w") as cfgFile:
                    #        cfgFile.write(confFileString)
                    #        print(f"\n{SWITCH_DIR} config file has been successfully written.\n") # USED FOR TESTING PURPOSES, ESPECIALLY ON WINDOWS WORKSTATIONS. Do not uncomment this unless
					#																				 you comment out the other "with open" file operation.
                else:
                    pass
                
            continueInput = input("\nCreate another config? (Y / N): ")
            if continueInput.lower() == "y":
                continue
            else:
			    if "win32" not in userOS:
                    os.system('clear')
                else:
                    os.system('cls') # only needed for testing the script on Windows workstations.
                print("Exiting with exit code: 0")
                exit(0)
            
        # Windows servers are being dumped in the same folder since we only have around 8 DCs and a couple other
        # Azure domain servers I don't know about. Not sure how many we're decommissioning but this should suffice for now.
        elif confSelect == "2":
            while True:
                print("\nYou have selected: Windows Server")
                HOSTNAME = input("\nPlease enter the hostname of the server (i.e. CPS216DC1): ")
                HOST_ALIAS = input("\nPlease enter the host alias of the server (i.e. JH Domain Controller): ")
                IP_ADDR = input("\nPlease enter the IP address of the server (i.e. 172.16.2.38): ")
                
                correctVals = input(f"\n\nDo these values look correct (Y / N)?\nHostname: {HOSTNAME}\nHost Alias: {HOST_ALIAS}\nIP Address: {IP_ADDR}\n\nInput: ")
                if correctVals.lower() == "y":
                    break
                else:
                    continue
                    
            today = datetime.now()
                    
            # Do not touch unless Nagios changes how formatting works for configs, or if you're adding another service for Nagios to check.
			# For other service checks, these must be defined in the host's respective original template (found in the /objects folder).
            confFileString = (
                f"# CONFIG GENERATED ON : {today.strftime('%m-%d-%Y %I:%M %p')}\n# BY NAGIOS CONFIG GENERATOR\n\n"
                "define host {\n"
                f"\tuse                     windows-server\n"
                f"\thost_name               {HOSTNAME}\n"
                f"\talias                   {HOST_ALIAS}\n"
                f"\taddress                 {IP_ADDR}\n"
                "\tcontact_groups          cps-network-alerts\n"
                "}\n\n")
            
            WINDOWS_DIR = f"/usr/local/nagios/etc/windows/{HOSTNAME}.cfg"
            # Also DO NOT TOUCH this; Nagios recommends installing to this location if you build it from
            # source like we did. If the path somehow changes, then go ahead and adjust this.
            if os.path.exists(WINDOWS_DIR):
                print("ERROR: The host you are trying to create already exists.")
            else:
                if checkIPforHost(IP_ADDR, userOS) == True:
                    with open(WINDOWS_DIR, "w") as cfgFile:
                    	cfgFile.write(confFileString)
                    	print(f"\n{WINDOWS_DIR} config file has been successfully written.\n")
                    #with open(f"{HOSTNAME}.cfg", "w") as cfgFile:
                    #        cfgFile.write(confFileString)
                    #        print(f"\n{SWITCH_DIR} config file has been successfully written.\n")
                else:
                    pass
                 
            continueInput = input("\nCreate another config? (Y / N): ")
            if continueInput.lower() == "y":
                continue
            else:
			    if "win32" not in userOS:
                    os.system('clear')
                else:
                    os.system('cls') # only needed for testing the script on Windows workstations.
                print("Exiting with exit code: 0")
                exit(0)        
            
        # For generic hosts or Linux machines. There's not enough Linux boxes in the district to justify splitting them off
        # in their own category for now. Mainly used for stuff like Powerschool, IPAM etc.
        elif confSelect == "3":
            while True:
                print("\nYou have selected: Generic Server")
                HOSTNAME = input("\nPlease enter the hostname of the server (i.e. powerschool.cowetaps.com): ")
                HOST_ALIAS = input("\nPlease enter the host alias of the server (i.e. Powerschool Server): ")
                IP_ADDR = input("\nPlease enter the IP address of the server (i.e. 172.16.2.38): ")
                
                correctVals = input(f"\n\nDo these values look correct (Y / N)?\nHostname: {HOSTNAME}\nHost Alias: {HOST_ALIAS}\nIP Address: {IP_ADDR}\n\nInput: ")
                if correctVals.lower() == "y": # Add nested if statement here to check and see if the IP is pingable.
                    break
                else:
                    continue
                
                
            today = datetime.now()
            
            # Do not touch unless Nagios changes how formatting works for configs, or if you're adding another service for Nagios to check.
			# For other service checks, these must be defined in the host's respective original template (found in the /objects folder).
            confFileString = (
            f"# CONFIG GENERATED ON : {today.strftime('%m-%d-%Y %I:%M %p')}\n# BY NAGIOS CONFIG GENERATOR\n\n"
            "define host {\n"
            f"\thost_name              {HOSTNAME}\n"
            f"\talias                  {HOST_ALIAS}\n"
            f"\taddress                {IP_ADDR}\n"
            "\tmax_check_attempts     3\n"
            "\tcheck_period           24x7\n"
            "\tcheck_command          check-host-alive\n"
            "\tcontact_groups         cps-network-alerts\n"
            "\tnotification_interval  60\n"
            "\tnotification_period    24x7\n"
            "}\n\n")
            
            GENERIC_DIR = f"/usr/local/nagios/etc/servers/{HOSTNAME}.cfg"
            if os.path.exists(GENERIC_DIR):
                print("ERROR: The host you are trying to create already exists.")
            else:
                if checkIPforHost(IP_ADDR, userOS) == True:
                    with open(GENERIC_DIR, "w") as cfgFile:
                    	cfgFile.write(confFileString)
                    	print(f"\n{GENERIC_DIR} config file has been successfully written.\n")
                    #with open(f"{HOSTNAME}.cfg", "w") as cfgFile:
                    #        cfgFile.write(confFileString)
                    #        print(f"\n{SWITCH_DIR} config file has been successfully written.\n")
                else:
                    pass
					
            continueInput = input("\nCreate another config? (Y / N): ")
            if continueInput.lower() == "y":
                continue
            else:
			    if "win32" not in userOS:
                    os.system('clear')
                else:
                    os.system('cls') # only needed for testing the script on Windows workstations.
                print("Exiting with exit code: 0")
                exit(0)            
                
        # Printers. I guess if we need to keep track of an annoying one that keeps breaking. Not putting email alerts on them to avoid spam.
        elif confSelect == "4":
            while True:
                print("\nYou have selected: Printer")
                HOSTNAME = input("\nPlease enter the hostname of the printer (i.e. JH_WR_COPIER): ")
                HOST_ALIAS = input("\nPlease enter the host alias of the printer (i.e. JH Teacher Copier): ")
                IP_ADDR = input("\nPlease enter the IP address of the printer (i.e. 172.16.2.38): ")
                
                correctVals = input(f"\n\nDo these values look correct (Y / N)?\nHostname: {HOSTNAME}\nHost Alias: {HOST_ALIAS}\nIP Address: {IP_ADDR}\n\nInput: ")
                if correctVals.lower() == "y":
                    break
                else:
                    continue
                    
            today = datetime.now()
            
            # Do not touch unless Nagios changes how formatting works for configs, or if you're adding another service for Nagios to check.
			# For other service checks, these must be defined in the host's respective original template (found in the /objects folder).
            confFileString = (
            f"# CONFIG GENERATED ON : {today.strftime('%m-%d-%Y %I:%M %p')}\n# BY NAGIOS CONFIG GENERATOR\n\n"
            "define host {\n"
            "\tuse                     generic-printer\n"
            f"\thost_name               {HOSTNAME}\n"
            f"\talias                   {HOST_ALIAS}\n"
            f"\taddress                 {IP_ADDR}\n"
            "\thostgroups              network-printers\n"
            "}\n\n"
            "define service {\n"
            "\tuse                     generic-service\n"
            f"\thost_name               {HOSTNAME}\n"
            "\tservice_description     PING\n"
            "\tcheck_command           check_ping!3000.0,80%!5000.0,100%\n"
            "\tcheck_interval          10\n"
            "\tretry_interval          1\n"
            "}\n\n")
            
            PRINTER_DIR = f"/usr/local/nagios/etc/printers/{HOSTNAME}.cfg"
            if os.path.exists(PRINTER_DIR):
                print("ERROR: The host you are trying to create already exists.")
            else:
                if checkIPforHost(IP_ADDR, userOS) == True:
                    with open(PRINTER_DIR, "w") as cfgFile:
                    	cfgFile.write(confFileString)
                    	print(f"\n{PRINTER_DIR} config file has been successfully written.\n")
                    #with open(f"{HOSTNAME}.cfg", "w") as cfgFile:
                    #        cfgFile.write(confFileString)
                    #        print(f"\n{SWITCH_DIR} config file has been successfully written.\n")
                else:
                    pass
            
            continueInput = input("\nCreate another config? (Y / N): ")
            if continueInput.lower() == "y":
                continue
            else:
			    if "win32" not in userOS:
                    os.system('clear')
                else:
                    os.system('cls') # only needed for testing the script on Windows workstations.
                print("Exiting with exit code: 0")
                exit(0)        
				
        elif confSelect == "5":
		    if "win32" not in userOS:
                os.system('clear')
            else:
                os.system('cls') # only needed for testing the script on Windows workstations.
            print("Exiting with exit code: 0")
            exit(0)            
        
        # If someone manages to make it to this line I'll be impressed.
        else:
            print("shouldn't have gotten here, that means there's an error :)")
			exit(1)
main()

