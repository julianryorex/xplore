import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xplore/core/navbar.dart';
import 'package:xplore/features/map/bloc/map_cubit.dart';

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
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  void changeCenterLocation(CameraPosition position) {
    final newCenter = LatLng(position.target.latitude, position.target.longitude);
    context.read<MapCubit>().updateCenter(newCenter);
  }

  /// Sets [GoogleMapController] and map style
  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController.setMapStyle(context.read<MapCubit>().mapStyle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const Navbar(),
      body: Stack(
        children: [
          BlocBuilder<MapCubit, MapStates>(
            builder: (context, state) {
              if (state is! LoadedMapState) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return GoogleMap(
                key: ValueKey<Object>(redrawKey),
                onMapCreated: onMapCreated,
                initialCameraPosition: MapCubit.initialCameraPosition,
                onCameraMove: changeCenterLocation,
                markers: state.markers,
                myLocationButtonEnabled: true, // TODO: false
                myLocationEnabled: true,
                onTap: (_) {},
              );
            },
          ),
        ],
      ),
    );
  }
}
