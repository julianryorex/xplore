import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/core/app_tab.dart';

class NavbarCubit extends Cubit<int> {
  NavbarCubit({AppTab initialTab = AppTab.home}) : super(initialTab.index);

  void setNavIndex(int index) => emit(index);

  void setTab(AppTab tab) => setNavIndex(tab.index);

  void reset() => setTab(AppTab.home);
}
