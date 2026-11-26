import 'dart:io';

import 'package:chaldea/models/db.dart';
import 'package:chaldea/packages/logger.dart';
import 'package:chaldea/utils/basic.dart';

/// 登录抓包入库。
///
/// 模块（LSPosed）hook 到游戏的 topLogin 响应体后，用 root 把它复制到
/// `<appPath>/sniff_inbox.txt`。App 启动或回到前台时取一次，读完即删，
/// 交给 `ImportHttpPage` 走与手动导入完全相同的逻辑。
///
/// 为什么放 appPath（/sdcard/Android/data/cc.narumi.chaldea）而不是 Download：
/// 这是 Chaldea 自己的外部私有目录，它本来就有读写权限，不需要
/// MANAGE_EXTERNAL_STORAGE，也不会在文件选择器里给用户塞一堆垃圾。
class SniffInbox {
  SniffInbox._();

  static const fileName = 'sniff_inbox.txt';

  /// 真实 topLogin 是 11MB 量级，64KB 以下基本可以判定写错了。
  static const kMinLength = 64 * 1024;

  static String get path => joinPaths(db.paths.appPath, fileName);

  /// 不读内容，只判断有没有待导入的文件。
  static bool get hasPending => File(path).existsSync();

  /// 取出待导入文本；取到即删。
  ///
  /// 静态游戏数据没就绪时 **不删文件**，留给下次启动/回前台重试。
  /// 否则首次安装还没下完数据就把登录包吃掉，用户会以为导入成功了，
  /// 但 updateFromMstData 里 `svt.dbSvt` 全是 null，一个从者都不会进。
  static Future<String?> take() async {
    final file = File(path);
    try {
      if (!await file.exists()) return null;
      if (!db.gameData.isValid) {
        logger.w('sniff inbox: 静态数据未就绪（isValid=false），保留文件等下次');
        return null;
      }
      final text = await file.readAsString();
      if (text.length < kMinLength) {
        await file.delete();
        logger.w('sniff inbox: 内容只有 ${text.length} 字符，已丢弃');
        return null;
      }
      await file.delete();
      logger.i('sniff inbox: 取到 ${text.length} 字符');
      return text;
    } catch (e, s) {
      logger.e('sniff inbox: 读取失败', e, s);
      return null;
    }
  }
}
