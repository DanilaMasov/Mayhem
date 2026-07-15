import 'momentum_state.dart';

abstract interface class MomentumRepository {
  Future<MomentumState> loadMomentum();

  Future<void> saveMomentum(MomentumState state);
}
