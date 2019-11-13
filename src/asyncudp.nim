import asyncdispatch, net, nativesockets, asyncnet

proc sendTo(socket: AsyncFD; address: string; port: Port; data: string): Future[void] {.async.} =
  var saddr: Sockaddr_storage
  var slen = sizeof(saddr).SockLen
  toSockAddr(address.parseIpAddress, port, saddr, slen)
  await sendTo(socket, unsafeAddr data[0], len(data), cast[ptr SockAddr](addr saddr), slen)

proc sendTo*(socket: AsyncSocket; address: string; port: Port; data: string): Future[void] {.async.} =
  runnableExamples:
    import asyncdispatch, net, nativesockets, asyncnet
    var sock = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    waitFor sock.sendTo("127.0.0.1", 1900.Port, "TEST2")    
    sock.close()
  #assert(socket.protocol != IPPROTO_TCP, "Cannot `sendTo` on a TCP socket")
  assert(not socket.isClosed, "Cannot `sendTo` on a closed socket")
  await sendTo(socket.getFd.AsyncFD, address, port, data)

proc recvFrom*(socket: AsyncSocket; length: int; flags: set[SocketFlag] = {}): Future[tuple[address: string, port: Port, data: string]] {.async.} = 
  runnableExamples:
    import asyncdispatch, net, nativesockets, asyncnet
    var socket = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    socket.bindAddr(1900.Port)
    const MSG_LEN = 16384 
    asyncCheck socket.recvFrom(MSG_LEN)
  # assert(socket.protocol != IPPROTO_TCP, "Cannot `recvFrom` on a TCP socket") # TODO when inside asyncnet; socket.protocol is private
  result.data.setLen(length)
  var saddr: Sockaddr_storage
  var slen = sizeof(saddr).SockLen
  var size = await recvFromInto(socket.getFd.AsyncFD, cast[cstring](addr result.data[0]),
                                length, cast[ptr SockAddr](addr(saddr)), # 16384
                                addr(slen), flags)
  # result.address = getAddrString(cast[ptr SockAddr](addr(saddr))) # works 
  # result.port = ntohs(saddr.sin_port).Port # is private to asyncnet, maybe later :)
  var ipaddr: IpAddress
  fromSockAddr(saddr, slen, ipaddr, result.port)
  result.address = $ipaddr
  result.data.setLen(size)

when isMainModule and false:
  var sock = newAsyncNativeSocket(nativesockets.AF_INET,
                                      nativesockets.SOCK_DGRAM,
                                      Protocol.IPPROTO_UDP)
  waitFor sock.sendTo("127.0.0.1", 9988.Port, "TEST")

when isMainModule and false:
  var sock = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  # sock.close()
  waitFor sock.sendTo("127.0.0.1", 9988.Port, "TEST2")

when isMainModule and false:
  var socket = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  socket.bindAddr(Port(8765))
  const MSG_LEN = 16384 
  while true:
    echo "R: ", waitFor socket.recvFrom(MSG_LEN, address, port)

when isMainModule and true:
  import multicast
  const
    HELLO_PORT = 1900
    HELLO_GROUP = "239.255.255.250" # router discovery  
    disc = """M-SEARCH * HTTP/1.1
    Host:239.255.255.250:1900
    ST:urn:schemas-upnp-org:device:InternetGatewayDevice:1
    Man:"ssdp:discover"
    MX:3""" & "\c\r\c\r"   
  var socket = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  echo socket.getFd.joinGroup(parseIpAddress(HELLO_GROUP))
  socket.bindAddr(Port(HELLO_PORT))
  const MSG_LEN = 16384 
  waitFor socket.sendTo(HELLO_GROUP, HELLO_PORT.Port, disc)
  while true:
    echo "R: ", waitFor socket.recvFrom(MSG_LEN)
