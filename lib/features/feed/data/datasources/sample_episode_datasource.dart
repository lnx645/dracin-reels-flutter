import '../models/episode_model.dart';

/// Data sampel UI saja, dari naskah orisinal "CINTA SANG PENGUASA QIN"
/// (Qin Chen dan Lin Yue). Bukan still/poster drama sungguhan, bukan
/// nama kreator asli. Nanti diganti sumber API/video tanpa mengubah domain.
class SampleEpisodeDataSource {
  List<EpisodeModel> getSampleEpisodes() {
    return const <EpisodeModel>[
      EpisodeModel(
        id: 'ep1',
        title: 'Hari Pertama Magang',
        number: 1,
        description:
            'Hari pertama magang Lin Yue di lobi Qin Group berubah saat '
            'lift berhenti di lantai yang salah.',
        hashtags: <String>['#CintaSangPenguasaQin', '#Dracin', '#Drama'],
        likes: 15200,
        comments: 4200,
        shares: 1200,
        gradient: <int>[0xFF3B1D5A, 0xFF0B0E14],
      ),
      EpisodeModel(
        id: 'ep2',
        title: 'Foto di Balik Bingkai',
        number: 2,
        description:
            'Di balik foto itu tertulis: Kontrak diputus, Qin Group, 2015. '
            'Lin Yue mulai merangkai potongan masa lalu.',
        hashtags: <String>['#CintaSangPenguasaQin', '#Dracin', '#Drama'],
        likes: 9800,
        comments: 1800,
        shares: 640,
        gradient: <int>[0xFF7A2E1F, 0xFF0B0E14],
      ),
      EpisodeModel(
        id: 'ep3',
        title: 'Pintu yang Terbuka',
        number: 3,
        description:
            'Qin Chen berdiri di pintu. Satu pertanyaan menggantung, dan '
            'tidak ada jalan kembali.',
        hashtags: <String>['#CintaSangPenguasaQin', '#Dracin', '#Drama'],
        likes: 21400,
        comments: 5300,
        shares: 2100,
        gradient: <int>[0xFF1F4A5A, 0xFF0B0E14],
      ),
      EpisodeModel(
        id: 'ep4',
        title: 'Rahasia Lin Wei',
        number: 4,
        description:
            'Ayah Lin Yue dijebak orang dalam Qin Group. Kebenaran mulai '
            'terkuak, satu per satu.',
        hashtags: <String>['#CintaSangPenguasaQin', '#Dracin', '#Drama'],
        likes: 7600,
        comments: 900,
        shares: 380,
        gradient: <int>[0xFF2E5A2E, 0xFF0B0E14],
      ),
      EpisodeModel(
        id: 'ep5',
        title: 'Pilihan Qin Chen',
        number: 5,
        description:
            'Pewaris Qin Group harus memilih antara keluarga dan kebenaran. '
            'Pilihan itu mengubah segalanya.',
        hashtags: <String>['#CintaSangPenguasaQin', '#Dracin', '#Drama'],
        likes: 18900,
        comments: 3100,
        shares: 1500,
        gradient: <int>[0xFF5A1F3B, 0xFF0B0E14],
      ),
    ];
  }
}
