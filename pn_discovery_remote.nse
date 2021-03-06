local nmap = require "nmap"
local stdnse = require "stdnse"
local string = require "string"
local table = require "table"
local bin = require "bin"
local packet = require "packet"
local math = require "math"
local shortport = require "shortport"

description = [[ This script scans a ip address range for profinet devices
and tries to get as much information about them as possible
]]
---
-- @usage
--
-- @output
--
-- @args
--
---
author = "Stefan Eiwanger"

license = "Same as Nmap--See http://nmap.org/book/man-legal.html"
categories = {"version", "discovery"} --safe?




--  check if the port 34964 is open (0x8894)
--portrule = shortport.port_or_service (34964, "profinet-cm", "closed")

--[[portrule = function(host, port)
	print("\nstart portrule\n")

if shortport.port_is_excluded(34964) then return false end

print(port.number)
print(port.protocol)
print(port.state)
if shortport.port_or_service (34964, "profinet-cm", {"tcp","udp"}) then
return true
end
end
--]]

hostrule = function(host, port)

print("rule!")
return true
end

--[[
hostrule = function()
print("\n\nstart rule\n\n")
	if nmap.address_family() ~= 'inet' then
		stdnse.print_debug("%s is IPv4 compatible only.",
		SCRIPT_NAME)
		print(nmap.address_family)
		print("endrule bad")
		return false
	end
	print("endrule safe")
	return true
end 
--]]




-- Print out a string in hex, for debugging. 
function print_hex(str) 
	
	if str == nil then
	return 
	end 
    local out = "%08x"..(" %02x"):rep(16).."   "; 
    local len, a = #str, 1; 
    repeat 
        if a + 16 > len then -- partial line? 

            io.write( 

           -- 00000000 AB CD EF GH JK 
           ("%08x"..(" %02x"):rep(len-a+1)..("   "):rep(17+a-len-1)):format( 
               a-1, str:byte(a, a+16)), 

           --                                          abcdefg\n 
           str:sub(a, a+16):gsub("%c", "."), "\n"); 

        else -- full line 

            io.write( 

           -- 00000000 AB CD EF GH JK LM NO PQ 
           out:format(a-1, str:byte(a, a+16)), 

           --                                    abcdefgh\n 
           str:sub(a, a+16):gsub("%c", "."), "\n"); 

        end 

        a = a + 16; 

    until a > len; 

    -- Print out the length 
    io.write(("         Length: %d [0x%x]\n"):format(len, len)) 

end 



function ByteCRC(sum, data)
 
   sum = sum ~ data
    for i = 0, 7 do     -- lua for loop includes upper bound, so 7, not 8
        if ((sum & 1) == 0) then
            sum = sum >> 1
        else
            sum = (sum >> 1) ~ 0xA001  -- it is integer, no need for string func
        end
    end
    return sum
end

function CRC(data, length)
    sum = 65535
    local d = 0
    for i = 1, length do
        d = string.byte(data, i)    -- get i-th element, like data[i] in C
        sum = ByteCRC(sum, d)
    end
    return sum
end



buildPacket = function(host, typeData)
	--[[local ippackt = packet.Frame:new()
	local udppackt = packet.Frame:new()
	local rpcpackt = packet.Frame:new()
	--]]

	local ippackt, udppackt, rpcpackt

	print(typeData.sport)
	--[[ version 4
	ippackt:ip_set_bin_dst(host.ip)
	ippackt:ip_set_bin_src(host.bin_ip_src)
	ippackt:ip_set_hl(5) -- default ip header
	ippackt:ip_set_id(typeData[ident_nmb])
	ippackt:ip_set_len(typeData[ipLength])
	 may checksum / lets see later
	--]]

	--[[
	udppackt:udp_set_sport(typeData.sport)
	udppackt:udp_set_dport(typeData.dport)
	udppackt:udp_set_length(typeData.udpLength)
	--]]

	udppackt = stdnse.tohex(typeData.sport) .. stdnse.tohex(typeData.dport) .. stdnse.tohex(typeData.udpLength)




	rpcpackt = stdnse.fromhex("04" .. "00" .. "2000" .. "100000" .. "00" .. "00000000000000000000000000000000" .. "0883afe11f5dc91191a408002b14a0fa" .. "01000000010001000100000100010001" .. "00000000" .."03000000" ..
	"03000000" .. "0200" .. "ffff" .. "ffff" .. "4c00" .. "0000" .. "00" .. "00" .. "00000000" .. "01000000" .. "00000000000000000000000000000000" .. 
	"02000000" .. "0100a0de976cd111827100a02442df7d" .. "0100" .. "0000" .. "01000000" .. "0000000000000000000000000000000000000000" .. "01000000")

	stdnse.tohex(host.bin_ip_src)
	stdnse.tohex(host.ip)
	stdnse.tohex(typeData.udpLength)
	stdnse.tohex(typeData.udpLength)
	stdnse.tohex(typeData.sport)
	stdnse.tohex(typeData.dport)

	print(stdnse.tohex(host.bin_ip_src))

	local pseudoheader = "11" .. stdnse.tohex(host.bin_ip_src) .. stdnse.tohex(host.bin_ip) .. stdnse.tohex(typeData.udpLength).. stdnse.tohex(typeData.udpLength) .. stdnse.tohex(typeData.sport) .. stdnse.tohex(typeData.dport) .. rpcpackt

	--ippackt = stdnse.fromhex("45" .. "00" ..typeData[ipLength] ..typeData[ident_nmb] .. "0000" .. "80" .. "11" .. --[[checksum]])
	--udppackt:udp_count_checksum()
	-- make payload a odd number
	if not (#pseudoheader % 2)   then pseudoheader = pseudoheader.. "00" end

	local checksum = CRC(pseudoheader, #pseudoheader)

	local payload = udppackt .. checksum .. rpcpackt



	local identnmb, err = stdnse.tohex(typeData.ident_nmb)
	stdnse.debug(1, "Error at building packet, parsing Identification Number. Reason: %s", err)
	
	while #identnmb < 4 do
		identnmb = "0" .. identnmb
	end
	

	local iplength, err = stdnse.tohex(typeData.ipLength)
	stdnse.debug(1, "Error at building packet, parsing ip length. Reason: %s", err)

	while #iplength < 4 do
		iplength = "0" .. iplength
	end

	ippackt = "45" .. "00" ..iplength .. identnmb .. "2000" .. "0000" .. "80" .. "11" -- checksum

	  
	local tmppacket = ippackt .. "0000" .. stdnse.tohex(host.bin_ip_src) .. stdnse.tohex(host.bin_ip)
	checksum = CRC(tmppacket  , #ippackt)
	print("\nip checksum:  " ..checksum)
	ippackt = ippackt .. stdnse.tohex(checksum) ..stdnse.tohex(host.bin_ip_src) .. stdnse.tohex(host.bin_ip) .. payload


	--ippackt = ippackt:build_ip_packet(host.bin_ip_src, host.bin_ip, payload, 0x00 , typeData.ident_nmb, 0, 0, 128, 4)

	print("\n\n" ..ippackt)
	print_hex(ippackt)

	typeData.ident_nmb = typeData.ident_nmb+1

	return ippackt
end






-- open ip socket and send an ip packet with udp packetload with rpc packetload
-- try out 
action = function(host,port)

print("action")
local IANA_PNIO_EPM_PORT = 34964

local IP_UDP_RPC_PACKETSIZE = 198
local UDP_RPC_EPM_PACKETSIZE = 164
local UDP_RPC_IM_PACKETSIZE = 172

local typeData = {}
 
local socket = nmap.new_socket("udp")
local dnet = nmap.new_dnet()

typeData.ident_nmb = 0
typeData.sport = IANA_PNIO_EPM_PORT
typeData.dport = IANA_PNIO_EPM_PORT
typeData.udpLength = UDP_RPC_IM_PACKETSIZE
typeData.ipLength = IP_UDP_RPC_PACKETSIZE



--table.insert(typeData, dport,IANA_PNIO_EPM_PORT)
--table.insert(typeData, udpLength,IANA_PNIO_EPM_PORT)

local packt = buildPacket(host,typeData)

print_hex(packt)

--[[
dnet:ip_open()
dnet:ip_send(packt, host.bin_ip)
dnet:ip_close()
--]]

socket:bind(nil, IANA_PNIO_EPM_PORT)
socket:connect(host, IANA_PNIO_EPM_PORT, "udp")
socket:send( packt )
socket:close()

--[[
-- doesn't need admin
socket:bind(nil, IANA_PNIO_EPM_PORT)
socket:sendto( host, IANA_PNIO_EPM_PORT, packt )
socket:close()
--]]


end

--[[
action = function(host, port)

end
--]]