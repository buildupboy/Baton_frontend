import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geocoding/geocoding.dart';

import 'location_picker_screen.dart';
import 'widgets/custom_input_field.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  static const Color _background = Color(0xFFF4F4F4);
  static const Color _submitOrange = Color(0xFFF7673B);
  static const Color _accentBrown = Color(0xFFB33010);

  static const List<String> _distanceOptions = [
    '3km',
    '5km',
    '7km',
    '10km',
    '15km',
    '21km',
  ];

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _placeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _membersController = TextEditingController();
  final _distanceController = TextEditingController();

  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 30);
  int _memberCount = 2;
  int _distanceIndex = 1;

  @override
  void initState() {
    super.initState();
    _syncTimeControllers();
    _syncMemberDistanceControllers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _placeNameController.dispose();
    _addressController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _membersController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  void _syncTimeControllers() {
    _startTimeController.text = _formatTimeKo(_startTime);
    _endTimeController.text = _formatTimeKo(_endTime);
  }

  void _syncMemberDistanceControllers() {
    _membersController.text = '$_memberCount명';
    _distanceController.text = _distanceOptions[_distanceIndex];
  }

  String _formatTimeKo(TimeOfDay t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final isPm = h >= 12;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${isPm ? '오후' : '오전'} $h12:$m';
  }

  /// 지도에서 좌표를 고른 뒤 역지오코딩으로 주소를 채웁니다.
  Future<void> _openMapPicker() async {
    final selected = await Navigator.of(context).push<NLatLng>(
      MaterialPageRoute<NLatLng>(
        builder: (_) => const LocationPickerScreen(),
      ),
    );
    if (!mounted || selected == null) return;

    try {
      await setLocaleIdentifier('ko_KR');
      final placemarks = await placemarkFromCoordinates(
        selected.latitude,
        selected.longitude,
      );

      if (placemarks.isEmpty) {
        setState(() {
          _addressController.text = '주소를 찾을 수 없습니다';
        });
        return;
      }

      final line = _koreanAddressLine(placemarks.first);
      setState(() {
        _addressController.text =
            line.isEmpty ? '주소를 찾을 수 없습니다' : line;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _addressController.text = '주소를 찾을 수 없습니다';
        });
      }
    }
  }

  /// [Placemark]에서 시·구·동 형태의 한국어 한 줄 주소를 만듭니다.
  String _koreanAddressLine(Placemark p) {
    final parts = <String>[];
    void add(String? s) {
      final t = s?.trim();
      if (t != null && t.isNotEmpty) parts.add(t);
    }

    add(p.administrativeArea);
    add(p.locality);
    add(p.subLocality);
    if (parts.isEmpty) {
      add(p.subAdministrativeArea);
      add(p.street);
      add(p.name);
    }
    return parts.join(' ');
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _startTime = picked;
      _startTimeController.text = _formatTimeKo(picked);
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _endTime = picked;
      _endTimeController.text = _formatTimeKo(picked);
    });
  }

  void _showMemberPicker() {
    var temp = _memberCount;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 280,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  '모집 인원',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: temp - 1,
                    ),
                    itemExtent: 40,
                    onSelectedItemChanged: (i) {
                      temp = i + 1;
                    },
                    children: List.generate(
                      5,
                      (i) => Center(
                        child: Text(
                          '${i + 1}명',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _memberCount = temp;
                          _membersController.text = '$_memberCount명';
                        });
                        Navigator.of(ctx).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _submitOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('확인'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDistancePicker() {
    var temp = _distanceIndex;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 280,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  '목표 거리',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: temp,
                    ),
                    itemExtent: 40,
                    onSelectedItemChanged: (i) => temp = i,
                    children: _distanceOptions
                        .map(
                          (e) => Center(
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _distanceIndex = temp;
                          _distanceController.text =
                              _distanceOptions[_distanceIndex];
                        });
                        Navigator.of(ctx).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _submitOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('확인'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          '새로운 러닝 모집',
          style: TextStyle(
            color: Color(0xFF1F1F1F),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomInputField(
                      label: '제목',
                      controller: _titleController,
                      hintText: '러닝 모집 제목을 입력하세요',
                    ),
                    const SizedBox(height: 20),
                    CustomInputField(
                      label: '모집 내용',
                      controller: _contentController,
                      hintText: '모집 내용을 입력하세요',
                      minLines: 3,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 20),
                    CustomInputField(
                      label: '장소명',
                      controller: _placeNameController,
                      hintText: '예: 반포 한강공원',
                    ),
                    const SizedBox(height: 20),
                    CustomInputField(
                      label: '주소',
                      controller: _addressController,
                      hintText: '지도에서 선택',
                      readOnly: true,
                      onTap: () {
                        _openMapPicker();
                      },
                      suffixIcon: const Icon(
                        Icons.location_on_rounded,
                        color: _accentBrown,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomInputField(
                            label: '시작 시간',
                            controller: _startTimeController,
                            readOnly: true,
                            onTap: _pickStartTime,
                            suffixIcon: const Icon(
                              Icons.access_time_filled_rounded,
                              color: _accentBrown,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: CustomInputField(
                            label: '종료 시간',
                            controller: _endTimeController,
                            readOnly: true,
                            onTap: _pickEndTime,
                            suffixIcon: const Icon(
                              Icons.schedule_rounded,
                              color: _accentBrown,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomInputField(
                            label: '모집 인원',
                            controller: _membersController,
                            readOnly: true,
                            onTap: _showMemberPicker,
                            suffixIcon: const Icon(
                              Icons.groups_rounded,
                              color: _accentBrown,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: CustomInputField(
                            label: '목표 거리',
                            controller: _distanceController,
                            readOnly: true,
                            onTap: _showDistancePicker,
                            suffixIcon: const Icon(
                              Icons.straighten_rounded,
                              color: _accentBrown,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _submitOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('글쓰기 완료'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
