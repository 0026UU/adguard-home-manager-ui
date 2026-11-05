import 'dart:convert';

import 'package:adguard_home_manager/constants/enums.dart';

class ServerInfo {
  LoadStatus loadStatus = LoadStatus.loading;
  ServerInfoData? data;

  ServerInfo({
    required this.loadStatus,
    this.data
  });
}

ServerInfoData serverInfoDataFromJson(String str) => ServerInfoData.fromJson(json.decode(str));

String serverInfoDataToJson(ServerInfoData data) => json.encode(data.toJson());

class ServerInfoData {
  final List<String> dnsAddresses;
  final int dnsPort;
  final int httpPort;
  final bool protectionEnabled;
  final bool dhcpAvailable;
  final bool running;
  final String version;
  final String language;

  /// The platform the server process runs on, and the moment it started. A
  /// stock AdGuard Home answers neither, so both stay null and the page leaves
  /// their rows out.
  final String? arch;
  final String? goos;
  final DateTime? startTime;

  ServerInfoData({
    required this.dnsAddresses,
    required this.dnsPort,
    required this.httpPort,
    required this.protectionEnabled,
    required this.dhcpAvailable,
    required this.running,
    required this.version,
    required this.language,
    this.arch,
    this.goos,
    this.startTime,
  });


  factory ServerInfoData.fromJson(Map<String, dynamic> json) => ServerInfoData(
    dnsAddresses: List<String>.from(json["dns_addresses"].map((x) => x)),
    dnsPort: json["dns_port"],
    httpPort: json["http_port"],
    protectionEnabled: json["protection_enabled"],
    dhcpAvailable: json["dhcp_available"] ?? false,
    running: json["running"],
    version: json["version"],
    language: json["language"],
    arch: json["arch"],
    goos: json["goos"],
    // The server reports its start as Unix milliseconds, and not as a whole
    // number of them.
    startTime: json["start_time"] is num
      ? DateTime.fromMillisecondsSinceEpoch((json["start_time"] as num).round())
      : null,
  );

  Map<String, dynamic> toJson() => {
    "dns_addresses": List<dynamic>.from(dnsAddresses.map((x) => x)),
    "dns_port": dnsPort,
    "http_port": httpPort,
    "protection_enabled": protectionEnabled,
    "dhcp_available": dhcpAvailable,
    "running": running,
    "version": version,
    "language": language,
    "arch": arch,
    "goos": goos,
    "start_time": startTime?.millisecondsSinceEpoch,
  };
}
