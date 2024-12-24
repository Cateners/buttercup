import { webview } from '@kit.ArkWeb';
import { AppUtil, DialogUtil, ResUtil } from '@pura/harmony-utils';
import { router, window } from '@kit.ArkUI';

@Entry
@Component
struct Game {
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      Web({
        src: Object(router.getParams())['address'],
        controller: this.controller
      }).domStorageAccess(true)
        .mediaPlayGestureAccess(false)
        .databaseAccess(true)
        .fileAccess(true)
        .initialScale(Object(router.getParams())['scale'])
        .onControllerAttached(() => {
          if (Object(router.getParams())['userAgent'] == true) {
            this.controller.setCustomUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" +
              " (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0");
          }
        })
        .onPageEnd(() => {
          if (Object(router.getParams())['touch2Mouse']) {
            this.controller.runJavaScript(ResUtil.getStringByNameSync("touch_to_mouse_patch"));
          }
          if (Object(router.getParams())['tyrano']) {
            this.controller.runJavaScript(ResUtil.getStringByNameSync("tyrano_patch"));
          }
          if (Object(router.getParams())['rmmv']) {
            this.controller.runJavaScript("Graphics._stretchEnabled = true;");
          }
        })
    }
  }

  aboutToAppear(): void {
    AppUtil.setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE);
    AppUtil.setStatusBar(false, false);
  }

  aboutToDisappear(): void {
    AppUtil.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    AppUtil.setStatusBar(false, true);
  }

  onBackPress(): boolean {
    if (this.controller.accessBackward()) {
      this.controller.backward();
      return true;
    }
    DialogUtil.showPrimaryDialog({
      message: $r("app.string.game_exit_hint"),
      primaryButton: {
        value: $r("app.string.dialog_cancel"),
        action: () => {}
      },
      secondaryButton: {
        value: $r("app.string.dialog_confirm"),
        fontColor: Color.Red,
        action: () => {
          router.back();
        }
      }
    });
    return true;
  }
}