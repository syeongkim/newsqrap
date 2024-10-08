import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import '../../services/reels_service.dart';
import 'package:provider/provider.dart';
import '../../services/user_provider.dart';
import 'article_detail_page.dart'; // 추가

class Reels extends StatefulWidget {
  const Reels({Key? key}) : super(key: key);

  @override
  _ReelsState createState() => _ReelsState();
}

class _ReelsState extends State<Reels> {
  List<dynamic> reels = [];
  bool isLoading = true;
  Map<int, VideoPlayerController> _controllers = {};
  final TextEditingController _commentController = TextEditingController();
  final ReelsService reelsService = ReelsService();

  @override
  void initState() {
    super.initState();
    fetchReels();
  }

  @override
  void dispose() {
    _disposeAllControllers();
    super.dispose();
  }

  void _disposeAllControllers() {
    _controllers.forEach((key, controller) {
      controller.dispose();
    });
    _controllers.clear();
  }

  Future<void> fetchReels() async {
    final date = DateTime.now().subtract(Duration(days: 1));
    final dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final url = Uri.parse('http://175.106.98.197:3000/reels/$dateString');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Fetched reels data: $data'); // 디버깅용 출력
        if (mounted) {
          setState(() {
            _disposeAllControllers();
            reels = data;
            isLoading = false;
          });
          _initializeAllVideoPlayers();
        }
      } else {
        throw Exception('Failed to load reels');
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> fetchReelsByOwner(String owner) async {
    try {
      setState(() {
        isLoading = true;
      });
      final data = await reelsService.fetchReelsByOwner(owner);
      print('Fetched reels by owner: $data');
      if (mounted) {
        setState(() {
          _disposeAllControllers();
          reels = data;
          isLoading = false;
        });
        _initializeAllVideoPlayers();
      }
    } catch (e) {
      print('Error fetching reels by owner: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _initializeAllVideoPlayers() {
    for (int i = 0; i < reels.length; i++) {
      initializeVideoPlayer(i, reels[i]['video'] ?? '');
    }
  }

  void initializeVideoPlayer(int index, String url) {
    print('Initializing video player for $url');
    var controller = VideoPlayerController.network(url);

    controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _controllers[index] = controller;
        });
      }
    }).catchError((err) {
      print('Error initializing video player: $err');
    });
  }

  Widget buildVideoWidget(int index) {
    VideoPlayerController controller = _controllers[index]!;
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            // 터치 시 재생 상태 토글
            setState(() {
              controller.value.isPlaying
                  ? controller.pause()
                  : controller.play();
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30), // 비디오를 둥글게 만듦
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child: !controller.value.isPlaying
                        ? Container(
                      color: Colors.black54,
                      child: Icon(Icons.play_arrow,
                          size: 50, color: Colors.white),
                    )
                        : SizedBox.shrink(), // 재생 중이면 아무것도 보여주지 않음
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 10),
        // 댓글 버튼과 기사 ID 버튼을 각각 별도의 둥근 네모 회색 컨테이너에 넣음
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: TextButton(
                onPressed: () => showComments(context, reels[index]['_id'] ?? '',
                    reels[index]['comments'] ?? []),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Row의 크기를 자식 요소에 맞춤
                  children: [
                    Icon(Icons.comment, color: Colors.black), // 댓글 아이콘
                    SizedBox(width: 4), // 아이콘과 텍스트 사이의 간격
                  ],
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: TextButton(
                onPressed: () {
                  final articleId = (reels[index]['articleId'] as List<dynamic>?)
                      ?.first
                      ?.toString();
                  print(articleId);
                  if (articleId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ArticleDetailPage(articleId: articleId),
                      ),
                    );
                  } else {
                    print("No articleId found for the selected reel.");
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Row의 크기를 자식 요소에 맞춤
                  children: [
                    Icon(Icons.newspaper, color: Colors.black),
                    SizedBox(width: 4),
                  ],
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void togglePlay(int index) {
    if (_controllers[index] != null) {
      setState(() {
        if (_controllers[index]!.value.isPlaying) {
          _controllers[index]!.pause();
        } else {
          _controllers[index]!.play();
        }
      });
    }
  }

  void showComments(BuildContext context, String reelId,
      List<dynamic> initialComments) async {
    Future<List<dynamic>> fetchComments() async {
      try {
        final updatedComments = await reelsService.getCommentsSorted(reelId);
        print('Fetched comments: $updatedComments');
        return updatedComments;
      } catch (e) {
        print("Error fetching comments: $e");
        return initialComments;
      }
    }

    List<dynamic> comments = await fetchComments();

    for (var comment in comments) {
      print('Comment _id: ${comment['_id']}');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                height: MediaQuery.of(context).size.height / 2,
                padding: EdgeInsets.all(13),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (BuildContext context, int index) {
                          var comment = comments[index];
                          print('Rendering comment: $comment');
                          return CommentTile(
                            reelId: reelId,
                            commentId: comment['_id'] ?? '',
                            nickname: comment['nickname'] ?? 'Anonymous',
                            content: comment['content'] ?? '',
                            likes: comment['likes'] ?? 0,
                            reelsService: reelsService,
                          );
                        },
                      ),
                    ),
                    TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: "Write a comment...",
                        suffixIcon: IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () async {
                            final userProvider = Provider.of<UserProvider>(
                                context,
                                listen: false);
                            final userId = userProvider.userId;
                            final nickname = userProvider.nickname;

                            try {
                              await reelsService.addComment(
                                  reelId,
                                  userId ?? '',
                                  nickname ?? '',
                                  _commentController.text);
                              print(
                                  "Submitted comment: ${_commentController.text}");

                              if (context.mounted) {
                                setModalState(() {
                                  comments.add({
                                    '_id': '',
                                    'nickname': nickname,
                                    'content': _commentController.text,
                                    'likes': 0,
                                  });
                                });

                                _commentController.clear();
                              }
                            } catch (e) {
                              print("Error adding comment: $e");
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 13),
          // 가로 스크롤 버튼 리스트
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0), // 양 옆에 패딩 적용
            child: Container(
              height: 100, // 버튼과 레이블을 포함할 충분한 높이 제공
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  buttonItem(
                      'assets/images/crabi.png', "NewsQrab", Colors.white),
                  buttonItem('assets/images/herald.png', "헤럴드경제", Colors.white),
                  buttonItem(
                      'assets/images/choseon.png', "조선 일보", Colors.white),
                  buttonItem(
                      'assets/images/sportsChoseon.png', "스포츠조선", Colors.white),
                  buttonItem('assets/images/ytn.png', "YTN", Colors.white),
                ],
              ),
            ),
          ),
          // 기존 비디오 리스트 로직
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: reels.length,
              itemBuilder: (context, index) {
                final reel = reels[index];
                if (!_controllers.containsKey(index)) {
                  initializeVideoPlayer(index, reel['video'] ?? '');
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: ListTile(
                    title: Text(reel['title'] ?? ''),
                    subtitle: _controllers.containsKey(index) &&
                        _controllers[index]!.value.isInitialized
                        ? buildVideoWidget(index)
                        : Container(
                        height: 200,
                        child: Center(
                            child: CircularProgressIndicator())),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buttonItem(String imagePath, String label, Color bgColor) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: () {
              print("$label tapped");
              fetchReelsByOwner(label); // 소유자별 릴스를 가져오는 메서드 호출
            },
            child: Image.asset(imagePath, width: 24, height: 24), // 이미지 크기 조절
            backgroundColor: bgColor,
          ),
          SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}

class CommentTile extends StatefulWidget {
  final String reelId;
  final String commentId;
  final String nickname;
  final String content;
  final int likes;
  final ReelsService reelsService;

  const CommentTile({
    Key? key,
    required this.reelId,
    required this.commentId,
    required this.nickname,
    required this.content,
    required this.likes,
    required this.reelsService,
  }) : super(key: key);

  @override
  _CommentTileState createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  late int _likes;

  @override
  void initState() {
    super.initState();
    _likes = widget.likes;
  }

  Future<void> _likeComment() async {
    try {
      print(widget);
      await widget.reelsService.likeComment(widget.reelId, widget.commentId);
      setState(() {
        _likes += 1;
      });
      // 상태 업데이트를 위젯 자체에서 처리
    } catch (e) {
      print("Error liking comment: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.nickname),
      subtitle: Text(widget.content),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.favorite),
            color: Colors.red,
            onPressed: _likeComment,
          ),
          Text('$_likes'),
        ],
      ),
    );
  }
}

