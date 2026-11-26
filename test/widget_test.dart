import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kuaforum/main.dart';
import 'package:kuaforum/data/kuaforum_feed_repository.dart';

class _FakeFeedRepository extends KuaforumFeedRepository {
  _FakeFeedRepository() : super(client: SupabaseClient('https://example.supabase.co', 'test-key'));
  final List<Map<String, dynamic>> data = [{
    'id':'comment-1','user_id':'another-user','author_name':'Ayşe Yılmaz',
    'body':'Çok güzel olmuş!','created_at':DateTime.now().toIso8601String(),
  }];
  @override
  Future<List<Map<String, dynamic>>> fetchComments(String postId) async =>
      data.map((item)=>Map<String,dynamic>.from(item)).toList();
  @override
  Future<void> addComment(String postId,String body) async {
    data.add({'id':'comment-${data.length+1}','user_id':'another-user',
      'author_name':'Test Kullanıcısı','body':body,'created_at':DateTime.now().toIso8601String()});
  }
  @override
  Future<void> deleteComment(String commentId) async { data.removeWhere((item)=>item['id']==commentId); }
}

void main() {
  testWidgets('comment sheet renders comments and sends a new comment', (tester) async {
    final repository=_FakeFeedRepository();
    tester.view.physicalSize=const Size(1000,1800);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:FeedCommentsSheet(postId:'post-1',repository:repository),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Yorumlar'),findsOneWidget);
    expect(find.text('Çok güzel olmuş!'),findsOneWidget);
    await tester.enterText(find.byType(TextField),'Yeni test yorumu');
    await tester.tap(find.text('Paylaş'));
    await tester.pumpAndSettle();
    expect(repository.data.any((item)=>item['body']=='Yeni test yorumu'),isTrue);
    expect(find.text('Yeni test yorumu'),findsOneWidget);
  });

  testWidgets('hero panel action responds to taps',(tester) async {
    var tapped=false;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:HeroPanel(
      eyebrow:'Test',title:'Test action',subtitle:'Action should work',
      icon:Icons.check_circle_outline,button:'Devam',onTap:()=>tapped=true,
    ))));
    await tester.tap(find.text('Devam'));
    expect(tapped,isTrue);
  });
}
