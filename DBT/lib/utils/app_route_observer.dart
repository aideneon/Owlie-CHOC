import 'package:flutter/material.dart';

/// Lets widgets pause work when another route covers them.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
