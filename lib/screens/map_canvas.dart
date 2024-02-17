import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xplore/core/navbar.dart';
import 'package:xplore/features/map/bloc/map_cubit.dart';

const _defaultCoordinates = LatLng(40.7128, -73.9571); // Williamsburg

class MapCanvas extends StatefulWidget {
  const MapCanvas({super.key});

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  /// Key that checks whether a rerender is necessary
  late Object redrawKey;

  /// Controller for [GoogleMap]
  late GoogleMapController mapController;

  @override
  void initState() {
    super.initState();

    redrawKey = Object();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const Navbar(),
      body: BlocBuilder<MapCubit, MapStates>(
        builder: (context, state) {
          if (state is InitialMapState) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return GoogleMap(
            key: ValueKey<Object>(redrawKey),
            onMapCreated: onMapCreated,
            initialCameraPosition: const CameraPosition(target: _defaultCoordinates, zoom: 5.0),
            // onCameraMove: changeCenterLocation,
            // onCameraMoveStarted: _onCameraMove,
            // markers: state is LoadedMapState ? state.markers.values.toSet() : {},
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
            onTap: (_) {},
          );
        },
      ),
    );
  }

  /// Sets [GoogleMapController] and map style
  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController.setMapStyle(context.read<MapCubit>().mapStyle);
  }
}
