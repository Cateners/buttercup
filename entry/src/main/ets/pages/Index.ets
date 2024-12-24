import { router } from '@kit.ArkUI';
import { zlib, BusinessError } from '@kit.BasicServicesKit';
import { socket } from '@kit.NetworkKit';
import { AppUtil, FileUtil, PickerUtil, ToastUtil,
  ResUtil, StrUtil, DialogUtil, PreferencesUtil, PreviewUtil} from '@pura/harmony-utils';
import { DialogHelper, DialogAction } from '@pura/harmony-dialog';
import { UnrarApi } from '@ohos/unrar';

interface FileList {
  files: string[];
  directories: string[];
}

interface GameInfo {
  engine: string;
  path: string; // relative
}

const HIDE_PATH = ".rawfile";

let tcpServer: socket.TCPSocketServer = socket.constructTCPSocketServerInstance();
let isTouch2MouseEnabled: boolean = PreferencesUtil.hasSync("isTouch2MouseEnabled")
  ? PreferencesUtil.getBooleanSync("isTouch2MouseEnabled") : false;
let isAirEnabled: boolean = PreferencesUtil.hasSync("isAirEnabled")
  ? PreferencesUtil.getBooleanSync("isAirEnabled") : false;
let zipCharEncoding: string = PreferencesUtil.hasSync("zipCharEncoding")
  ? PreferencesUtil.getStringSync("zipCharEncoding") : "default";
let initialScale: number = PreferencesUtil.hasSync("initialScale")
  ? PreferencesUtil.getNumberSync("initialScale") : 100;
let customUserAgent: boolean = PreferencesUtil.hasSync("customUserAgent")
  ? PreferencesUtil.getBooleanSync("customUserAgent") : false;
let isTyranoGame = false;
let isRmmvGame = false;

@Component
struct Settings {
  @Consume('pageInfos') pageInfos: NavPathStack;
  @State encodeHint: ResourceStr = `< ${ResUtil.getStringByNameSync("zip_encoding_" + zipCharEncoding)} >`;
  @State initialScaleText: string = initialScale.toString();

  build() {
    NavDestination() {
      Column({space: 12}) {
        Row() {
          Text($r("app.string.touch_to_mouse"))
          Toggle({ type: ToggleType.Switch, isOn: isTouch2MouseEnabled }).onChange((isOn) => {
            PreferencesUtil.putSync("isTouch2MouseEnabled", isOn);
            isTouch2MouseEnabled = isOn;
          })
        }.justifyContent(FlexAlign.SpaceBetween).width("100%")
        Divider()
        Row() {
          Text($r("app.string.ruffle_runtime"))
          Toggle({ type: ToggleType.Switch, isOn: isAirEnabled }).onChange((isOn) => {
            PreferencesUtil.putSync("isAirEnabled", isOn);
            isAirEnabled = isOn;
          })
        }.justifyContent(FlexAlign.SpaceBetween).width("100%")
        /*
        Divider()
        Row() {
          Text($r("app.string.scale_hint"))
          Text(this.initialScaleText)
        }.justifyContent(FlexAlign.SpaceBetween).width("100%")
        Slider({
          value: initialScale,
          min: 50,
          max: 200,
          step: 10,
          //style: SliderStyle.OutSet
        }).onChange((n, m) => {
          this.initialScaleText = n.toString();
          if (m == SliderChangeMode.End) {
            PreferencesUtil.putSync("initialScale", n);
            initialScale = n;
          }
        })
        Divider()
        Row() {
          Text($r("app.string.user_agent_hint"))
          Toggle({ type: ToggleType.Switch, isOn: customUserAgent }).onChange((isOn) => {
            PreferencesUtil.putSync("customUserAgent", isOn);
            customUserAgent = isOn;
          })
        }.justifyContent(FlexAlign.SpaceBetween).width("100%")*/
        // Row() {
        //   Text($r("app.string.zip_encoding"))
        //   Text(this.encodeHint).onClick(() => {
        //     let buttons = ["default", "en", "sc", "tc", "jp"];
        //     DialogUtil.showDialog({
        //       title: $r("app.string.zip_encoding"),
        //       message: "",
        //       buttons: buttons.map(v => ResUtil.getStringByNameSync("zip_encoding_" + v)),
        //       onAction: (action) => {
        //         PreferencesUtil.putSync("zipCharEncoding", buttons[Math.abs(action)-1]);
        //         zipCharEncoding = buttons[Math.abs(action)-1];
        //         this.encodeHint = `< ${ResUtil.getStringByNameSync("zip_encoding_" + zipCharEncoding)} >`;
        //       }
        //     })
        //   })
        // }.justifyContent(FlexAlign.SpaceBetween).width("100%")
      }.width('100%').height('100%').padding(12)
    }.title(ResUtil.getStringByNameSync("setting"))
    .backgroundColor($r("app.color.navigation_background"))
    .onBackPressed(() => {
      const popDestinationInfo = this.pageInfos.pop()
      console.log('pop' + '返回值' + JSON.stringify(popDestinationInfo))
      return true
    })
  }
}

@Entry
@Component
struct Index {
  @State fileList: FileList = getSortedFileList(FileUtil.getFilesDirPath());
  @State currentPath: string = "/";
  currentFile: string = "";

  @Provide('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  @Builder
  PageMap(name: string) {
    Settings()
  }

  build() {
    Column() {
      Navigation(this.pageInfos) {
        Text(ResUtil.getStringByNameSync("current_path_hint") + ` ${this.currentPath} `)
          .width("100%")
          .margin({ left: 12 })
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
        List({ space: 12 }) {
          if (this.currentPath != "/") {
            ListItem() {
              Row() {
                Image($r("app.media.folder")).width(20).height(20)
                Text("..").margin(12)
              }
            }
            .width("100%")
            .align(Alignment.Start)
            .onClick(() => {
              this.currentPath = this.currentPath.slice(0,
                this.currentPath.lastIndexOf('/', this.currentPath.length - 2) + 1
              );
              this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
            })
          }
          ForEach(this.fileList.directories, (item: string) => {
            ListItem() {
              Row() {
                Image(
                  getGameType(this.currentPath + '/' + item) == ""
                    ? $r("app.media.folder")
                    : $r("app.media.folder_right")
                ).width(20).height(20)
                Text(item).margin(12)
              }
            }
            .width("100%")
            .align(Alignment.Start)
            .onClick(() => {
              this.currentPath += item + '/';
              try {
                this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
              } catch {
                this.currentPath = this.currentPath.slice(0,
                  this.currentPath.lastIndexOf('/', this.currentPath.length - 2) + 1
                );
                this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                ToastUtil.showToast(` ${item} ` + ResUtil.getStringByNameSync("corrupted_file"));
              }
            })
            .gesture(LongPressGesture().onAction(() => {
              DialogUtil.showPrimaryDialog({
                title: item,
                message: $r("app.string.delete_hint"),
                primaryButton: {
                  value: $r("app.string.dialog_cancel"),
                  action: () => {
                  }
                },
                secondaryButton: {
                  value: $r("app.string.dialog_confirm"),
                  fontColor: Color.Red,
                  action: () => {
                    ToastUtil.showToast(ResUtil.getStringByNameSync("delete_start") + ` ${item} `);
                    FileUtil.rmdir(FileUtil.getFilesDirPath(this.currentPath, item)).then(() => {
                      this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                      ToastUtil.showToast(ResUtil.getStringByNameSync("delete_success") + ` ${item} `);
                    }).catch((err: BusinessError) => {
                      console.error(`Code is ${err.code}, message is ${err.message}`);
                      ToastUtil.showToast(` ${item} ` + ResUtil.getStringByNameSync("delete_fail"));
                    })
                  }
                }
              });
            }))
          })
          ForEach(this.fileList.files, (item: string) => {
            ListItem() {
              Row() {
                Image(
                  isCompressedFile(item) ? $r("app.media.briefcase")
                    : maybePlayable(item) ? $r("app.media.playable") : $r("app.media.doc")
                ).width(20).height(20)
                Text(item).margin(12)
              }
            }
            .width("100%")
            .align(Alignment.Start)
            .onClick(() => {
              isTyranoGame = false;
              isRmmvGame = false;
              if (item.endsWith(".zip")) {
                DialogUtil.showPrimaryDialog({
                  title: item,
                  message: $r("app.string.uncompress_hint"),
                  primaryButton: {
                    value: $r("app.string.dialog_cancel"),
                    action: () => {
                    }
                  },
                  secondaryButton: {
                    value: $r("app.string.dialog_confirm"),
                    fontColor: Color.Red,
                    action: () => {
                      ToastUtil.showToast(ResUtil.getStringByNameSync("uncompress_start") + ` ${item} `);
                      let foo = FileUtil.getFilesDirPath(this.currentPath, item.slice(0, item.lastIndexOf('.')));
                      let bar = this.currentPath + item.slice(0, item.lastIndexOf('.')) + '/';
                      try { FileUtil.mkdirSync(foo); } catch {}
                      zlib.decompressFile(FileUtil.getFilesDirPath(this.currentPath, item), foo).then(() => {
                        this.currentPath = bar;
                        try {
                          this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                          ToastUtil.showToast(ResUtil.getStringByNameSync("uncompress_success") + ` ${item} `);
                        } catch {
                          this.currentPath = this.currentPath.slice(0,
                            this.currentPath.lastIndexOf('/', this.currentPath.length - 2) + 1
                          );
                          this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                          ToastUtil.showToast(` ${item.slice(0, item.lastIndexOf('.'))} `
                            + ResUtil.getStringByNameSync("zip_encoding_error")
                          );
                        }
                      }).catch((err: BusinessError) => {
                        console.error(`Code is ${err.code}, message is ${err.message}`);
                        ToastUtil.showToast(` ${item} ` + ResUtil.getStringByNameSync("uncompress_fail"));
                      })
                    }
                  }
                });
                return;
              }
              if (item.endsWith(".asar")) {
                DialogUtil.showPrimaryDialog({
                  title: item,
                  message: $r("app.string.uncompress_hint"),
                  primaryButton: {
                    value: $r("app.string.dialog_cancel"),
                    action: () => {
                    }
                  },
                  secondaryButton: {
                    value: $r("app.string.dialog_confirm"),
                    fontColor: Color.Red,
                    action: () => {
                      ToastUtil.showToast(ResUtil.getStringByNameSync("uncompress_start") + ` ${item} `);
                      let foo = FileUtil.getFilesDirPath(this.currentPath, item.slice(0, item.lastIndexOf('.')));
                      let bar = this.currentPath + item.slice(0, item.lastIndexOf('.')) + '/';
                      try { FileUtil.mkdirSync(foo); } catch {}
                      extractAsar(FileUtil.getFilesDirPath(this.currentPath, item), foo).then(() => {
                        this.currentPath = bar;
                        this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                        ToastUtil.showToast(ResUtil.getStringByNameSync("uncompress_success") + ` ${item} `);
                      }).catch((err: BusinessError) => {
                        console.error(`Code is ${err.code}, message is ${err.message}`);
                        ToastUtil.showToast(` ${item} ` + ResUtil.getStringByNameSync("uncompress_fail"));
                      })
                    }
                  }
                });
                return;
              }
              if (item.endsWith(".rar")) {
                DialogUtil.showPrimaryDialog({
                  title: item,
                  message: $r("app.string.uncompress_hint"),
                  primaryButton: {
                    value: $r("app.string.dialog_cancel"),
                    action: () => {
                    }
                  },
                  secondaryButton: {
                    value: $r("app.string.dialog_confirm"),
                    fontColor: Color.Red,
                    action: () => {
                      let file_encrypted = false;
                      try {
                        file_encrypted = UnrarApi.isEncrypted(FileUtil.getFilesDirPath(this.currentPath, item)) == 0;
                      } catch {
                        console.error(`Message is err`);
                        ToastUtil.showToast(` ${item} ` + ResUtil.getStringByNameSync("corrupted_file"));
                        return;
                      }
                      if (file_encrypted) {
                        ToastUtil.showToast(ResUtil.getStringByNameSync("uncompress_start") + ` ${item} `);
                        let foo = FileUtil.getFilesDirPath(this.currentPath, item.slice(0, item.lastIndexOf('.')));
                        let bar = this.currentPath + item.slice(0, item.lastIndexOf('.')) + '/';
                        try { FileUtil.mkdirSync(foo); } catch {}
                        UnrarApi.RarFiles_Extract(FileUtil.getFilesDirPath(this.currentPath, item), foo, {
                          callBackResult: (value: string) => {
                            if (value == '解压成功') {
                              this.currentPath = bar;
                              this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                              ToastUtil.showToast(ResUtil.getStringByNameSync("uncompress_success") + ` ${item} `);
                            } else {
                              console.error(`Message is ${value}`);
                              ToastUtil.showToast(` ${item} ` + ResUtil.getStringByNameSync("uncompress_fail"));
                            }
                          }
                        });
                        return;
                      }
                      DialogHelper.showTextInputDialog({
                        title: $r("app.string.uncompress_password_hint"),
                        text: "",
                        onAction: (action, dialogId, content) => {
                          if (action == DialogAction.TWO) {
                            ToastUtil.showToast(ResUtil.getStringByNameSync("uncompress_start") + ` ${item} `);
                            let foo =
                              FileUtil.getFilesDirPath(this.currentPath, item.slice(0, item.lastIndexOf('.')));
                            let bar = this.currentPath + item.slice(0, item.lastIndexOf('.')) + '/';
                            try { FileUtil.mkdirSync(foo); } catch {}
                            UnrarApi.RarFiles_Extract(FileUtil.getFilesDirPath(this.currentPath, item), foo, {
                              callBackResult: (value: string) => {
                                if (value == '解压成功') {
                                  this.currentPath = bar;
                                  this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                                  ToastUtil.showToast(ResUtil.getStringByNameSync("uncompress_success") +
                                    ` ${item} `);
                                } else {
                                  console.error(`Message is ${value}`);
                                  ToastUtil.showToast(` ${item} ` + ResUtil.getStringByNameSync("uncompress_fail"));
                                }
                              }
                            }, content);
                          }
                        }
                      })
                    }
                  }
                });
                return;
              }
              if (item.endsWith(".swf")) {
                FileUtil.writeEasy(
                  FileUtil.getFilesDirPath("", HIDE_PATH + "/ruffle/flash.html"),
                  FileUtil.readTextSync(FileUtil.getFilesDirPath("", HIDE_PATH + "/ruffle/index.html")).replace(
                    "FLASH_FILE", this.currentPath.slice(1) + item
                  ).replace(
                    "FLASH_DIR", this.currentPath.slice(1)
                  ).replace(
                    "EXTRA_OPTIONS", isAirEnabled ? "playerRuntime: \"air\"," : ""
                  ),
                  false
                ).then(() => {
                  launchGame("/" + HIDE_PATH + "/ruffle/flash.html");
                });
              }
              if (item.endsWith(".exe")) {
                let gameType = getGameType(this.currentPath);
                if ((gameType == "resources/app.asar") && !FileUtil.accessSync(
                  FileUtil.getFilesDirPath(this.currentPath, "resources/app")
                )) {
                  DialogUtil.showPrimaryDialog({
                    message: $r("app.string.unpack_asar_hint"),
                    primaryButton: {
                      value: $r("app.string.dialog_cancel"),
                      action: () => {}
                    },
                    secondaryButton: {
                      value: $r("app.string.dialog_confirm"),
                      fontColor: Color.Red,
                      action: () => {
                        ToastUtil.showToast(ResUtil.getStringByNameSync("uncompress_start") + ` app.asar `);
                        let foo = FileUtil.getFilesDirPath(this.currentPath, "resources/app");
                        let bar = this.currentPath;
                        try { FileUtil.mkdirSync(foo); } catch {}
                        extractAsar(FileUtil.getFilesDirPath(this.currentPath, "resources/app.asar"), foo).then(() => {
                          this.currentPath = bar;
                          this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                          ToastUtil.showToast(ResUtil.getStringByNameSync("uncompress_success") + ` app.asar `);
                        }).catch((err: BusinessError) => {
                          console.error(`Code is ${err.code}, message is ${err.message}`);
                          ToastUtil.showToast(` app.asar ` + ResUtil.getStringByNameSync("uncompress_fail"));
                        })
                      }
                    }
                  });
                  return;
                }
                if (gameType.endsWith(".html")) {
                  const gamePath = this.currentPath + gameType;
                  isTyranoGame = FileUtil.accessSync(
                    FileUtil.getParentPath(FileUtil.getFilesDirPath("", gamePath.slice(1))) + "/tyrano"
                  );
                  isRmmvGame = FileUtil.accessSync(
                    FileUtil.getParentPath(FileUtil.getFilesDirPath("", gamePath.slice(1))) + "/js/rpg_core.js"
                  );
                  launchGame(gamePath);
                  return;
                }
                
                ToastUtil.showToast(ResUtil.getStringByNameSync("unsupported_type"));
                return;
              }
              if (item.endsWith(".html")) {
                isTyranoGame = FileUtil.accessSync(FileUtil.getFilesDirPath(this.currentPath, "tyrano"));
                isRmmvGame = FileUtil.accessSync(FileUtil.getFilesDirPath(this.currentPath, "js/rpg_core.js"));
                launchGame(this.currentPath + item);
                return;
              }
              let itemUri: string = FileUtil.getUriFromPath(
                FileUtil.getFilesDirPath(this.currentPath.slice(1, -1), item)
              );
              PreviewUtil.canPreview(itemUri).then((canPreview) => {
                if (canPreview) {
                  console.error(itemUri)
                  PreviewUtil.openPreviewEasy(itemUri);
                }
              });
            })
            .gesture(LongPressGesture().onAction(() => {
              DialogUtil.showPrimaryDialog({
                title: item,
                message: $r("app.string.delete_hint"),
                primaryButton: {
                  value: $r("app.string.dialog_cancel"),
                  action: () => {
                  }
                },
                secondaryButton: {
                  value: $r("app.string.dialog_confirm"),
                  fontColor: Color.Red,
                  action: () => {
                    ToastUtil.showToast(ResUtil.getStringByNameSync("delete_start") + ` ${item} `);
                    FileUtil.unlink(FileUtil.getFilesDirPath(this.currentPath, item)).then(() => {
                      this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                      ToastUtil.showToast(ResUtil.getStringByNameSync("delete_success") + ` ${item} `);
                    }).catch((err: BusinessError) => {
                      console.error(`Code is ${err.code}, message is ${err.message}`);
                      ToastUtil.showToast(` ${item} ` + ResUtil.getStringByNameSync("delete_fail"));
                    })
                  }
                }
              });
            }))
          })
          if ((this.fileList.files.length + this.fileList.directories.length) == 0) {
            ListItem() {
              Text(ResUtil.getStringByNameSync("empty")).width("100%").textAlign(TextAlign.Center)
            }
          }
        }
        .height("100%")
        .margin(12)
        .scrollBar(BarState.Auto)
      }
      .navDestination(this.PageMap)
      .title($r("app.string.app_title"))
      .menus([
        {
          value: ResUtil.getStringByNameSync("info"),
          icon: "resources/base/media/info.svg",
          action: () => {
            DialogUtil.showConfirmDialog({
              title: ResUtil.getStringByNameSync("info"),
              message: ResUtil.getStringByNameSync("info_text")
            })
          }
        },
        {
          value: ResUtil.getStringByNameSync("refresh"),
          icon: "resources/base/media/refresh.svg",
          action: () => {
            this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
            ToastUtil.showToast(ResUtil.getStringByNameSync("refreshed"));
          }
        },
        {
          value: ResUtil.getStringByNameSync("setting"),
          icon: "resources/base/media/slider.svg",
          action: () => {
            this.pageInfos.pushPath({ name: "settings" });
          }
        },
        {
          value: ResUtil.getStringByNameSync("folder_add"),
          icon: "resources/base/media/folder_add.svg",
          action: () => {
            DialogHelper.showTextInputDialog({
              title: $r("app.string.folder_add"),
              text: "",
              onAction: (action, dialogId, content) => {
                if (action == DialogAction.TWO) {
                  FileUtil.mkdir(FileUtil.getFilesDirPath(this.currentPath, content), false).then(() => {
                    this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                    ToastUtil.showToast(ResUtil.getStringByNameSync("folder_add_success") + ` ${content} `);
                  }).catch((err: BusinessError) => {
                    console.error(`Code is ${err.code}, message is ${err.message}`)
                    ToastUtil.showToast(` ${content} ` + ResUtil.getStringByNameSync("folder_add_fail"));
                  })
                }
              }
            })
          }
        },
        {
          value: ResUtil.getStringByNameSync("file_import"),
          icon: "resources/base/media/move_in.svg",
          action: () => {
            PickerUtil.selectDocument().then((uris) => {
              if (uris.length == 0) {
                return;
              }
              this.currentFile = FileUtil.getFileName(uris[0]);
              ToastUtil.showToast(ResUtil.getStringByNameSync("move_in_start") + ` ${this.currentFile} `);
              FileUtil.copyFile(FileUtil.getFilePath(uris[0]),
                FileUtil.getFilesDirPath(this.currentPath, this.currentFile)
              ).then(() => {
                this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
                ToastUtil.showToast(ResUtil.getStringByNameSync("move_in_success") + ` ${this.currentFile} `);
              });
            }).catch((err: BusinessError) => {
              console.error(`Code is ${err.code}, message is ${err.message}`)
              ToastUtil.showToast(` ${this.currentFile} ` + ResUtil.getStringByNameSync("move_in_fail"));
            })
          }
        }
      ])
      .hideBackButton(true)
      .mode(NavigationMode.Stack)
      .height('100%')
      .width('100%')
      .backgroundColor($r("app.color.navigation_background"))
    }
  }
  aboutToAppear(): void {
    AppUtil.setStatusBar(false, true);
    copyRawFile();
    startServer();
  }
  onBackPress(): boolean | void {
    if (this.currentPath == '/') return false;
    this.currentPath = this.currentPath.slice(0,
      this.currentPath.lastIndexOf('/', this.currentPath.length - 2) + 1
    );
    this.fileList = getSortedFileList(FileUtil.getFilesDirPath(this.currentPath));
    return true;
  }
}

function getSortedFileList(path: string): FileList {
  let ret: FileList = {files: [], directories: []};
  for (let item of FileUtil.listFileSync(path)) {
    if (FileUtil.getFilesDirPath(path, item)
      == FileUtil.getFilesDirPath("/", HIDE_PATH)
      || FileUtil.getFilesDirPath(path, item)
      == FileUtil.getFilesDirPath("", HIDE_PATH)) {
      continue;
    }
    if (FileUtil.isDirectory(FileUtil.getFilesDirPath(path, item))) {
      ret.directories.push(item);
      continue;
    }
    ret.files.push(item);
  }
  ret.directories.sort();
  ret.files.sort();
  return ret;
}

function isCompressedFile(name: string) {
  for (let i of [".zip", ".rar", ".7z", ".asar"]) {
    if (name.endsWith(i)) return true;
  }
  return false;
}

function maybePlayable(name: string) {
  for (let i of [".exe", ".swf", ".html"]) {
    if (name.endsWith(i)) return true;
  }
  return false;
}

function getGameType(path: string): string {
  const GAME_INFO: GameInfo[] = [{
    engine: "RPG Maker MV",
    path: "www/index.html"
  }, {
    engine: "Electron Unpacked",
    path: "resources/app/out/renderer/index.html"
  }, {
    engine: "Electron Unpacked",
    path: "resources/app/renderer/index.html"
  }, {
    engine: "TyranoBuilder Unpacked",
    path: "resources/app/index.html"
  }, {
    engine: "CocosCreator Unpacked",
    path: "resources/app/web/index.html"
  }, {
    engine: "Electron",
    path: "resources/app.asar"
  }, {
    engine: "Web",
    path: "index.html"
  }]
  for (let i of GAME_INFO) {
    if (FileUtil.accessSync(FileUtil.getFilesDirPath(path, i.path))) return i.path;
  }
  return "";
}

function buildMimeString(path: string) {
  const pos = path.lastIndexOf('.');
  if (pos < 0) return "";
  let ret = "";
  switch (path.slice(pos)) {
    case ".html": ret = "text/html; charset=utf-8"; break;
    case ".js": ret = "text/javascript; charset=utf-8"; break;
    case ".wasm": ret = "application/wasm"; break;
    default: return "";
  }
  return "Content-Type: " + ret + " \r\n";
}

function startServer() {
  tcpServer.listen({
    address: "0.0.0.0",
    port: 23333,
    family: 1
  }, (err: BusinessError) => {
    if (err) {
      ToastUtil.showToast(ResUtil.getStringByNameSync("start_server_fail"));
      return;
    }
    ToastUtil.showToast(ResUtil.getStringByNameSync("start_server_success"));
  })

  tcpServer.on('connect', (clientSocket: socket.TCPSocketConnection) => {
    clientSocket.on('message', (msgInfo: socket.SocketMessageInfo) => {
      let requestMessage = StrUtil.bufferToStr(msgInfo.message).split(' ')[1];
      let i = requestMessage.indexOf('?');
      let relativePath = decodeURIComponent(i < 0 ? requestMessage : requestMessage.slice(0, i)).slice(1);
      let requestPath = FileUtil.getFilesDirPath("", relativePath);
      console.error(requestPath)
      let bufferSize = 0;
      let ab: ArrayBuffer;
      let isFileNotFound = !FileUtil.accessSync(requestPath) || !FileUtil.isFile(requestPath);
      console.error(FileUtil.accessSync(requestPath)?"true1":"false1")
      if (isFileNotFound) {
        // relativePath is like "abc/aaa/aaa/eg.txt"
        // detect if sth like "aBC/Aaa/aaA/Eg.TXT" exists
        let buildPath = "/";
        for (const step of relativePath.split('/')) {
          isFileNotFound = true;
          if (FileUtil.accessSync(FileUtil.getFilesDirPath("/", buildPath + step))) {
            buildPath += step + '/';
            isFileNotFound = false;
            continue;
          }
          for (const eachFile of FileUtil.listFileSync(FileUtil.getFilesDirPath(buildPath))) {
            if (eachFile.toLowerCase() == step.toLowerCase()) {
              buildPath += eachFile + '/';
              isFileNotFound = false;
              break;
            }
          }
          if (isFileNotFound) break;
        }
        if (!isFileNotFound) {
          requestPath = FileUtil.getFilesDirPath("", buildPath.slice(1, -1));
          isFileNotFound = !FileUtil.accessSync(requestPath) || !FileUtil.isFile(requestPath);
        }
      }
      if (!isFileNotFound) {
        bufferSize += FileUtil.getFileDirSize(requestPath);
        let f = FileUtil.openSync(requestPath);
        ab = new ArrayBuffer(FileUtil.getFileDirSize(requestPath));
        FileUtil.readSync(f.fd, ab);
        FileUtil.closeSync(f);
      } else {
        ToastUtil.showToast(ResUtil.getStringByNameSync("not_found") + ` ${requestPath} `);
        bufferSize = 13;
        ab = StrUtil.strToBuffer("<html></html>");
      }
      let headerStr = "HTTP/1.1 200 OK \r\n"
        + "Content-Length: " + bufferSize.toString() + " \r\n"
        + (isFileNotFound ? "" : buildMimeString(requestPath))
        + "\r\n"
      let headerBuffer = StrUtil.strToBuffer(headerStr);
      let resultBuffer = new ArrayBuffer(bufferSize + headerBuffer.byteLength);
      let resultView = new Uint8Array(resultBuffer);
      resultView.set(new Uint8Array(headerBuffer), 0);
      resultView.set(new Uint8Array(ab), headerBuffer.byteLength);
      clientSocket.send({ data: resultBuffer });
    })
  });
}

function stopServer() {
  tcpServer.off('connect');
}

function launchGame(path: string) {
  router.pushUrl({ url: 'pages/Game', params: {
    address: `http://localhost:23333${path}`,
    touch2Mouse: isTouch2MouseEnabled,
    tyrano: isTyranoGame,
    rmmv: isRmmvGame,
    scale: initialScale,
    userAgent: customUserAgent
  }}).then(() => {
    console.info('Succeeded in jumping to the second page.')
  }).catch((err: BusinessError) => {
    console.error(`Failed to jump to the second page. Code is ${err.code}, message is ${err.message}`)
  })
}

async function extractAsar(path: string, to: string) {

  const f = await FileUtil.open(path);
  let asarBuffer: ArrayBuffer = new ArrayBuffer(FileUtil.getFileDirSize(path));
  await FileUtil.read(f.fd, asarBuffer);
  await FileUtil.close(f);

  await processFiles((
    JSON.parse(
      StrUtil.bufferToStr(
        asarBuffer.slice(16, 16 + new DataView(asarBuffer.slice(12, 16)).getUint32(0, true))
      )
    ) as FileEntry
  ).files,
    asarBuffer.slice(12 + new DataView(asarBuffer.slice(8, 12)).getUint32(0, true)), to
  );
}

interface Integrity {
  algorithm: string;
  hash: string;
  blockSize: number;
  blocks: string[];
}

interface FileMetadata {
  offset: string;
  size: number;
  executable?: boolean;
  integrity?: Integrity;
}

interface FileEntry {
  files: Record<string, FileMetadata | FileEntry>;
}

// 处理文件目录并递归解压文件
async function processFiles(files: Record<string, FileMetadata | FileEntry>,
  asarBuffer: ArrayBuffer, currentDir: string) {
  for (let eachFile of Object.entries(files)) {
    const fileName = eachFile[0];
    const fileData = eachFile[1];

    // 如果是目录，递归处理子目录
    if ((fileData as FileEntry).files) {
      const nextFiles = (fileData as FileEntry).files;
      const newDir = `${currentDir}/${fileName}`;
      await FileUtil.mkdir(newDir);  // 确保目录存在
      await processFiles(nextFiles, asarBuffer, newDir);
    } else {
      // 处理文件
      const fileInfo = fileData as FileMetadata;
      const offset = Number(fileInfo.offset); // 文件的偏移量
      const size = fileInfo.size; // 文件的大小
      const fileBuffer = asarBuffer.slice(offset, offset + size);
      const filePath = `${currentDir}/${fileName}`;
      await FileUtil.writeEasy(filePath, fileBuffer, false); // 写入文件到目标路径
    }
  }
}

async function copyRawFile() {
  if (await FileUtil.access(FileUtil.getFilesDirPath(HIDE_PATH, "001"))) {
    return;
  }
  try {await FileUtil.mkdir(FileUtil.getFilesDirPath(HIDE_PATH, "ruffle"), true);} catch {}
  for (let i of [
    "ruffle/20f2ed2f33119240ff9c.wasm",
    "ruffle/80948b0c0c5db153dbcd.wasm",
    "ruffle/core.ruffle.6324012080f931a06ac6.js",
    "ruffle/core.ruffle.6324012080f931a06ac6.js.map",
    "ruffle/ruffle.js",
    "ruffle/ruffle.js.map",
    "ruffle/index.html"
  ]) {
    try {await FileUtil.writeEasy(
      FileUtil.getFilesDirPath(HIDE_PATH, i),
      (await ResUtil.getRawFileContent(i)).buffer,
      false
    );}
    catch {}
  }
  try {await FileUtil.writeEasy(FileUtil.getFilesDirPath(HIDE_PATH, "001"), "001", false);} catch {}
}