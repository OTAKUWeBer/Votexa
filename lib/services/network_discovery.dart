import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';

class NetworkDiscovery {
  static const String _votexaServiceType = '_votexa._tcp';
  static const int _discoveryTimeoutSeconds = 5;

  static Future<Map<String, String>> discoverVotexaHosts() async {
    final Map<String, String> hosts = {};

    try {
      final MDnsClient client = MDnsClient();
      await client.start();

      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.PTR(_votexaServiceType))) {
        await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.SRV(ptr.domainName))) {
          // Try to get IPv4 address
          await for (final ResourceRecord aRecord in client
              .lookup<ResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))) {
            if (aRecord is AResourceRecord) {
              hosts[srv.name] = '${aRecord.address}:${srv.port}';
            }
          }
        }
      }

      await client.stop();
    } catch (e) {
      print('[NetworkDiscovery] Error discovering hosts: $e');
    }

    return hosts;
  }

  static Future<String?> resolveHostAddress(String hostName) async {
    try {
      final InternetAddress address =
          await InternetAddress.lookup(hostName).then((list) => list.first);
      return address.address;
    } catch (e) {
      print('[NetworkDiscovery] Error resolving host: $e');
      return null;
    }
  }

  static Future<bool> checkConnectivity() async {
    try {
      final result =
          await InternetAddress.lookup('8.8.8.8', type: InternetAddressType.any);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (e) {
      print('[NetworkDiscovery] No internet connectivity');
    }
    return false;
  }
}
