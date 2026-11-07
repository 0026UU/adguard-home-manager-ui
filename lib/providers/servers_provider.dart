import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:adguard_home_manager/models/github_release.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/services/external_requests.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/update_available.dart';
import 'package:adguard_home_manager/functions/conversions.dart';
import 'package:adguard_home_manager/services/db/queries.dart';
import 'package:adguard_home_manager/providers/error_reason.dart';
import 'package:adguard_home_manager/constants/enums.dart';

class ServersProvider with ChangeNotifier, ErrorReason {
  Database? _dbInstance;

  List<Server> _serversList = [];
  Server? _selectedServer;
  // ApiClient? _apiClient;
  ApiClientV2? _apiClient2;

  bool _updatingServer = false;

  final UpdateAvailable _updateAvailable = UpdateAvailable(
    loadStatus: LoadStatus.loading,
    data: null,
  );

  // ApiClient? get apiClient {
  //   return _apiClient;
  // }

  ApiClientV2? get apiClient2 {
    return _apiClient2;
  }

  List<Server> get serversList {
    return _serversList;
  }

  Server? get selectedServer {
    return _selectedServer;
  }

  UpdateAvailable get updateAvailable {
    return _updateAvailable;
  }

  bool get updatingServer {
    return _updatingServer;
  }

  void setDbInstance(Database db) {
    _dbInstance = db;
  }

  void addServer(Server server) {
    _serversList.add(server);
    notifyListeners();
  }

  void setSelectedServer(Server? server) {
    _selectedServer = server;
    notifyListeners();
  }

  void setUpdateAvailableLoadStatus(LoadStatus status, bool notify) {
    _updateAvailable.loadStatus = status;
    if (notify == true) {
      notifyListeners();
    }
  }

  void setUpdateAvailableData(UpdateAvailableData data) {
    _updateAvailable.data = data;
    notifyListeners();
  }

  // void setApiClient(ApiClient client) {
  //   _apiClient = client;
  //   notifyListeners();
  // }

  void setApiClient2(ApiClientV2 client) {
    _apiClient2 = client;
    notifyListeners();
  }

  void setUpdatingServer(bool status) {
    _updatingServer = status;
    notifyListeners();
  }

  Future<dynamic> createServer(Server server) async {
    final saved = await saveServerQuery(_dbInstance!, server);
    if (saved == null) {
      if (server.defaultServer == true) {
        final defaultServer = await setDefaultServer(server);
        if (defaultServer == null) {
          _serversList.add(server);
          notifyListeners();
          return null;
        }
        else {
          return defaultServer;
        }
      }
      else {
        _serversList.add(server);
        notifyListeners();
        return null;
      }
    }
    else {
      return saved;
    }
  }

  Future<dynamic> setDefaultServer(Server server) async {
    final updated = await setDefaultServerQuery(_dbInstance!, server.id);
    if (updated == null) {
      List<Server> newServers = _serversList.map((s) {
        if (s.id == server.id) {
          s.defaultServer = true;
          return s;
        }
        else {
          s.defaultServer = false;
          return s;
        }
      }).toList();
      _serversList = newServers;
      notifyListeners();
      return null;
    }
    else {
      return updated;
    }
  }

  Future<dynamic> editServer(Server server) async {
    final result = await editServerQuery(_dbInstance!, server);
    if (result == null) {
      List<Server> newServers = _serversList.map((s) {
        if (s.id == server.id) {
          return server;
        }
        else {
          return s;
        }
      }).toList();
      _serversList = newServers;

      if (selectedServer != null &&server.id == selectedServer!.id) {
        // _apiClient = ApiClient(server: server);
        _apiClient2 = ApiClientV2(server: server);
      }

      notifyListeners();
      return null;
    }
    else {
      return result;
    }
  }

  Future<bool> removeServer(Server server) async {
    final result = await removeServerQuery(_dbInstance!, server.id);
    if (result == true) {
      // Only the server that is on screen loses its client; dropping the
      // selection wholesale would log the user out of a different server, and
      // keeping the client would let every screen go on reading and writing a
      // row that no longer exists.
      final wasSelected = _selectedServer?.id == server.id;
      if (wasSelected) {
        _apiClient2 = null;
        _selectedServer = null;
      }
      _serversList = _serversList.where((s) => s.id != server.id).toList();

      // Deleting the connection in use must not strand the app on the
      // two-tab bar while saved connections still work, so the next row takes
      // over — and takes the default flag with it, or the next launch is
      // stranded again with nothing the user can do about it.
      if (wasSelected && _serversList.isNotEmpty) {
        final next = _serversList.firstWhere(
          (s) => s.defaultServer == true,
          orElse: () => _serversList.first,
        );
        _selectedServer = next;
        _apiClient2 = ApiClientV2(server: next);
        if (next.defaultServer != true) {
          unawaited(setDefaultServer(next));
        }
      }

      notifyListeners();
      return true;
    }
    else {
      return false;
    }
  }

  void checkServerUpdatesAvailable({
    required Server server, 
    ApiClientV2? apiClient
  }) async {
    final client = apiClient ?? _apiClient2;
    setUpdateAvailableLoadStatus(LoadStatus.loading, true);
    final result = await client!.checkServerUpdates();
    if (result.successful == true) {
      UpdateAvailableData data = UpdateAvailableData.fromJson(result.content);
      // A server that answers {"disabled": true} names no release, so asking
      // GitHub for one would only delay the answer the page is waiting for.
      if (data.disabled != true) {
        final gitHubResult = await ExternalRequests.getReleaseData(releaseTag: data.newVersion ?? data.currentVersion);
        if (gitHubResult.successful == true) {
          data.changelog = (gitHubResult.content as GitHubRelease).body;
        }
      }
      setUpdateAvailableData(data);
      setUpdateAvailableLoadStatus(LoadStatus.loaded, true);
    }
    else {
      setUpdateAvailableLoadStatus(LoadStatus.error, true);
    }
  }

  Future initializateServer(Server server, /*ApiClient apiClient, */ ApiClientV2 apiClient2) async {
    final serverStatus = await _apiClient2!.getServerStatus();
    if (serverStatus.successful == true) {
      checkServerUpdatesAvailable( // Do not await
        server: server,
        apiClient: apiClient2
      ); 
    }
  }

  Future saveFromDb(List<Map<String, dynamic>>? data) async {
    if (data != null) {
      Server? defaultServer;
      for (var server in data) {
        final Server serverObj = Server(
          id: server['id'],
          name: server['name'],
          connectionMethod: server['connectionMethod'],
          domain: server['domain'],
          path: server['path'],
          port: server['port'],
          user: server['user'],
          password: server['password'],
          defaultServer: convertFromIntToBool(server['defaultServer'])!,
          authToken: server['authToken'],
          runningOnHa: convertFromIntToBool(server['runningOnHa'])!,
        );
        _serversList.add(serverObj);
        if (convertFromIntToBool(server['defaultServer']) == true) {
          defaultServer = serverObj;
        }
      }

      notifyListeners();

      if (defaultServer != null) {
        _selectedServer = defaultServer;
        // final client = ApiClient(server: defaultServer);
        final client2 = ApiClientV2(server: defaultServer);
        // _apiClient = client;
        _apiClient2 = client2;
        initializateServer(defaultServer, /*client,*/ client2);
      }
    }
    else {
      notifyListeners();
      return null;
    }
  }

  void recheckPeriodServerUpdated() {
    if (_selectedServer == null) return;

    // A server with the update check switched off answers /control/version.json
    // with {"disabled": true} and no new version at all, so the comparison in
    // the timer below can never be satisfied: the poll would keep firing every
    // two seconds for as long as the app is open, over a screen that has
    // nothing to show. There is nothing to watch, so nothing is started.
    if (_updateAvailable.data?.disabled == true) return;

    setUpdatingServer(true);
    Server server = _selectedServer!;
    Timer.periodic(
      const Duration(seconds: 2), 
      (timer) async {
        if (_selectedServer != null && _selectedServer == server) {
          final result = await _apiClient2!.checkServerUpdates();
          if (result.successful == true) {
            UpdateAvailableData data = UpdateAvailableData.fromJsonUpdate(result.content);
            // The same answer can arrive while the poll is running: the server
            // reports the update as finished by switching the check off, and
            // then it never reports a new version either.
            if (data.disabled == true) {
              timer.cancel();
              setUpdatingServer(false);
              return;
            }
            if (data.currentVersion == data.newVersion) {
              final gitHubResult = await ExternalRequests.getReleaseData(releaseTag: data.newVersion ?? data.currentVersion);
              if (gitHubResult.successful == true) {
                data.changelog = (gitHubResult.content as GitHubRelease).body;
              }
              setUpdateAvailableData(data);
              timer.cancel();
              setUpdatingServer(false);
            }
          }
          else {
            timer.cancel();
            setUpdatingServer(false);
          }
        }
        else {
          timer.cancel();
          setUpdatingServer(false);
        }
      }
    );
  }
}