import 'dart:convert';

import 'package:adguard_home_manager/constants/enums.dart';

/// The order a fresh install starts from.
///
/// Blocked domains come first because that is the ranking the overview card
/// opens on: the first entry of this list is the segment the card selects
/// before the user has chosen one.
final List<HomeTopItems> homeTopItemsDefaultOrder = [
  HomeTopItems.blockedDomains,
  HomeTopItems.queriedDomains,
  HomeTopItems.recurrentClients,
];

final String homeTopItemsDefaultOrderString = jsonEncode(
  List<String>.from(homeTopItemsDefaultOrder.map((e) => e.name))
);
