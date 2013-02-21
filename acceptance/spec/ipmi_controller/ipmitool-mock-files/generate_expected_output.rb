#!/usr/bin/env ruby

require 'yaml'

# impitool bmc info output
ipmitool_bmc_info_out = {}
eval 'ipmitool_bmc_info_out = {:Device_ID=>"33", :Device_Revision=>"1", :Firmware_Revision=>"0.54", :IPMI_Version=>"2.0", :Manufacturer_ID=>"343", :Manufacturer_Name=>"Intel Corporation", :Product_ID=>"62 (0x003e)", :Product_Name=>"Unknown (0x3E)", :Device_Available=>"yes", :Provides_Device_SDRs=>"no", :Additional_Device_Support=>["Sensor Device", "SDR Repository Device", "SEL Device", "FRU Inventory Device", "IPMB Event Receiver", "IPMB Event Generator", "Chassis Device"], :Aux_Firmware_Rev_Info=>["0x00", "0x18", "0x00", "0x54"]}'

# impitool bmc getenables output
ipmitool_bmc_getenables_out = {}
eval 'ipmitool_bmc_getenables_out = {:Receive_Message_Queue_Interrupt=>"enabled", :Event_Message_Buffer_Full_Interrupt=>"disabled", :Event_Message_Buffer=>"disabled", :System_Event_Logging=>"enabled", :OEM_0=>"disabled", :OEM_1=>"disabled", :OEM_2=>"disabled"}'

# impitool bmc guid output
ipmitool_bmc_guid_out = {}
eval 'ipmitool_bmc_guid_out = {:System_GUID=>"21fac037-7ad7-df11-bce8-001517fae034", :Timestamp=>"01/24/1988 22:55:35"}'

# impitool chassis status output
ipmitool_chassis_status_out = {}
eval 'ipmitool_chassis_status_out = {:System_Power=>"on", :Power_Overload=>"false", :Power_Interlock=>"inactive", :Main_Power_Fault=>"false", :Power_Control_Fault=>"false", :Power_Restore_Policy=>"previous", :Last_Power_Event=>"command", :Chassis_Intrusion=>"inactive", :"Front-Panel_Lockout"=>"inactive", :Drive_Fault=>"false", :"Cooling/Fan_Fault"=>"false", :Sleep_Button_Disable=>"not allowed", :Diag_Button_Disable=>"allowed", :Reset_Button_Disable=>"allowed", :Power_Button_Disable=>"allowed", :Sleep_Button_Disabled=>"false", :Diag_Button_Disabled=>"false", :Reset_Button_Disabled=>"false", :Power_Button_Disabled=>"false"}'

# impitool lan print output
ipmitool_lan_print_out = {}
eval 'ipmitool_lan_print_out = {:Set_in_Progress=>"Set Complete", :Auth_Type_Support=>"NONE MD5 PASSWORD", :Auth_Type_Enable=>["Callback : NONE MD5 PASSWORD", "User     : NONE MD5 PASSWORD", "Operator : NONE MD5 PASSWORD", "Admin    : PASSWORD", "OEM      :"], :IP_Address_Source=>"DHCP Address", :IP_Address=>"192.168.2.51", :Subnet_Mask=>"255.255.255.0", :MAC_Address=>"00:15:17:fa:e0:36", :SNMP_Community_String=>"INTEL", :IP_Header=>"TTL=0x00 Flags=0x00 Precedence=0x00 TOS=0x00", :BMC_ARP_Control=>"ARP Responses Enabled, Gratuitous ARP Disabled", :Gratituous_ARP_Intrvl=>"0.0 seconds", :Default_Gateway_IP=>"192.168.2.32", :Default_Gateway_MAC=>"00:00:00:00:00:00", :Backup_Gateway_IP=>"0.0.0.0", :Backup_Gateway_MAC=>"00:00:00:00:00:00", :"8021q_VLAN_ID"=>"Disabled", :"8021q_VLAN_Priority"=>"0", :"RMCP+_Cipher_Suites"=>"1,2,3,6,7,8,11,12,0", :Cipher_Suite_Priv_Max=>["caaaXXaaaXXaaXX", "X=Cipher Suite Unused", "c=CALLBACK", "u=USER", "o=OPERATOR", "a=ADMIN", "O=OEM"]}'

# impitool fru print output
ipmitool_fru_print_out = {}
eval 'ipmitool_fru_print_out = {:FRU_Device_Description=>"Pwr Supply 1 FRU (ID 2)", :Chassis_Type=>"Rack Mount Chassis", :Chassis_Part_Number=>"..................", :Chassis_Serial=>"..................", :Chassis_Extra=>"...............................", :Board_Mfg_Date=>"Tue Oct 12 21:54:00 2010", :Board_Mfg=>"Intel Corporation", :Board_Product=>"S5520UR", :Board_Serial=>"BZUB04203606", :Board_Part_Number=>"E22554-751", :Product_Manufacturer=>"DELTA", :Product_Name=>"DPS-650QB A", :Product_Part_Number=>"E33446-007", :Product_Version=>"02F", :Product_Serial=>"E33446D1033007009", :Product_Asset_Tag=>"...................."}'

YAML::dump(ipmitool_bmc_info_out, File.open('bmc-info.yaml', 'w'))
YAML::dump(ipmitool_bmc_getenables_out, File.open('bmc-getenables.yaml', 'w'))
YAML::dump(ipmitool_bmc_guid_out, File.open('bmc-guid.yaml', 'w'))
YAML::dump(ipmitool_chassis_status_out, File.open('chassis-status.yaml', 'w'))
YAML::dump(ipmitool_lan_print_out, File.open('lan-print.yaml', 'w'))
YAML::dump(ipmitool_fru_print_out, File.open('fru-print.yaml', 'w'))
