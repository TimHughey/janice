webpackJsonp(["main"],{

/***/ "./src/$$_lazy_route_resource lazy recursive":
/***/ (function(module, exports) {

function webpackEmptyAsyncContext(req) {
	// Here Promise.resolve().then() is used instead of new Promise() to prevent
	// uncatched exception popping up in devtools
	return Promise.resolve().then(function() {
		throw new Error("Cannot find module '" + req + "'.");
	});
}
webpackEmptyAsyncContext.keys = function() { return []; };
webpackEmptyAsyncContext.resolve = webpackEmptyAsyncContext;
module.exports = webpackEmptyAsyncContext;
webpackEmptyAsyncContext.id = "./src/$$_lazy_route_resource lazy recursive";

/***/ }),

/***/ "./src/app/app-routing.module.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return AppRoutingModule; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__angular_core__ = __webpack_require__("./node_modules/@angular/core/esm5/core.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1__angular_router__ = __webpack_require__("./node_modules/@angular/router/esm5/router.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_2__landing_landing_component__ = __webpack_require__("./src/app/landing/landing.component.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_3__remotes_remotes_component__ = __webpack_require__("./src/app/remotes/remotes.component.ts");
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};




var routes = [
    { path: '', redirectTo: '/landing', pathMatch: 'full' },
    { path: 'landing', component: __WEBPACK_IMPORTED_MODULE_2__landing_landing_component__["a" /* LandingComponent */] },
    { path: 'remotes', component: __WEBPACK_IMPORTED_MODULE_3__remotes_remotes_component__["a" /* RemotesComponent */] }
];
var AppRoutingModule = /** @class */ (function () {
    function AppRoutingModule() {
    }
    AppRoutingModule = __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["NgModule"])({
            imports: [__WEBPACK_IMPORTED_MODULE_1__angular_router__["RouterModule"].forRoot(routes)],
            exports: [__WEBPACK_IMPORTED_MODULE_1__angular_router__["RouterModule"]]
        })
    ], AppRoutingModule);
    return AppRoutingModule;
}());



/***/ }),

/***/ "./src/app/app.component.css":
/***/ (function(module, exports) {

module.exports = ".fancy-font {\n  padding-top: 0px;\n  color: #6111e4 !important;\n  font-family: 'Permanent Marker', cursive;\n}\n"

/***/ }),

/***/ "./src/app/app.component.html":
/***/ (function(module, exports) {

module.exports = "<div class=\"row justify-content-center\" style=\"padding-bottom:50px\">\n  <div class=\"col-md-11\">\n    <router-outlet></router-outlet>\n  </div>\n</div>\n\n<div class=\"row justify-content-center\">\n  <div class=\"col-md-auto\">\n    <h5>Here are some links to help you start:</h5>\n  </div>\n</div>\n\n<div class=\"row justify-content-center\">\n  <div class=\"col-md-auto\">\n    <h5><a routerLink=\"/landing\">Landing</a></h5>\n  </div>\n  <div class=\"col-md-auto\">\n    <h5><a routerLink=\"/remotes\">Remotes</a></h5>\n  </div>\n  <div class=\"col-md-auto \">\n    <h5><a target=\"_blank \" rel=\"noopener \" href=\"https://angular.io/tutorial \">Tour of Heroes</a></h5>\n  </div>\n  <div class=\"col-md-auto \">\n    <h5><a target=\"_blank \" rel=\"noopener \" href=\"https://github.com/angular/angular-cli/wiki \">CLI Documentation</a></h5>\n  </div>\n  <div class=\"col-md-auto \">\n    <h5><a target=\"_blank \" rel=\"noopener \" href=\"https://blog.angular.io/ \">Angular blog</a></h5>\n  </div>\n</div>"

/***/ }),

/***/ "./src/app/app.component.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return AppComponent; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__angular_core__ = __webpack_require__("./node_modules/@angular/core/esm5/core.js");
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};

var AppComponent = /** @class */ (function () {
    function AppComponent() {
    }
    AppComponent.prototype.ngOnInit = function () { };
    AppComponent = __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Component"])({
            selector: 'app-root',
            template: __webpack_require__("./src/app/app.component.html"),
            styles: [__webpack_require__("./src/app/app.component.css")]
        })
    ], AppComponent);
    return AppComponent;
}());



/***/ }),

/***/ "./src/app/app.module.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return AppModule; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__angular_platform_browser__ = __webpack_require__("./node_modules/@angular/platform-browser/esm5/platform-browser.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1__angular_platform_browser_animations__ = __webpack_require__("./node_modules/@angular/platform-browser/esm5/animations.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_2__angular_core__ = __webpack_require__("./node_modules/@angular/core/esm5/core.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_3__angular_common_http__ = __webpack_require__("./node_modules/@angular/common/esm5/http.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_4__angular_forms__ = __webpack_require__("./node_modules/@angular/forms/esm5/forms.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_5_angular2_fontawesome_angular2_fontawesome__ = __webpack_require__("./node_modules/angular2-fontawesome/angular2-fontawesome.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_5_angular2_fontawesome_angular2_fontawesome___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_5_angular2_fontawesome_angular2_fontawesome__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_6_primeng_primeng__ = __webpack_require__("./node_modules/primeng/primeng.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_6_primeng_primeng___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_6_primeng_primeng__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_7_primeng_checkbox__ = __webpack_require__("./node_modules/primeng/checkbox.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_7_primeng_checkbox___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_7_primeng_checkbox__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_8_primeng_confirmdialog__ = __webpack_require__("./node_modules/primeng/confirmdialog.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_8_primeng_confirmdialog___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_8_primeng_confirmdialog__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_9_primeng_inputtext__ = __webpack_require__("./node_modules/primeng/inputtext.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_9_primeng_inputtext___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_9_primeng_inputtext__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_10_primeng_menu__ = __webpack_require__("./node_modules/primeng/menu.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_10_primeng_menu___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_10_primeng_menu__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_11_primeng_menubar__ = __webpack_require__("./node_modules/primeng/menubar.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_11_primeng_menubar___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_11_primeng_menubar__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_12_primeng_messages__ = __webpack_require__("./node_modules/primeng/messages.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_12_primeng_messages___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_12_primeng_messages__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_13_primeng_components_common_messageservice__ = __webpack_require__("./node_modules/primeng/components/common/messageservice.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_13_primeng_components_common_messageservice___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_13_primeng_components_common_messageservice__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_14_primeng_progressspinner__ = __webpack_require__("./node_modules/primeng/progressspinner.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_14_primeng_progressspinner___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_14_primeng_progressspinner__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_15_primeng_table__ = __webpack_require__("./node_modules/primeng/table.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_15_primeng_table___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_15_primeng_table__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_16_primeng_togglebutton__ = __webpack_require__("./node_modules/primeng/togglebutton.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_16_primeng_togglebutton___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_16_primeng_togglebutton__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_17__app_component__ = __webpack_require__("./src/app/app.component.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_18__remotes_remote_table_component__ = __webpack_require__("./src/app/remotes/remote-table.component.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_19__remotes_remote_service__ = __webpack_require__("./src/app/remotes/remote.service.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_20__app_routing_module__ = __webpack_require__("./src/app/app-routing.module.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_21__landing_landing_component__ = __webpack_require__("./src/app/landing/landing.component.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_22__subsystems_subsystems_component__ = __webpack_require__("./src/app/subsystems/subsystems.component.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_23__remotes_remotes_component__ = __webpack_require__("./src/app/remotes/remotes.component.ts");
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
























var AppModule = /** @class */ (function () {
    function AppModule() {
    }
    AppModule = __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_2__angular_core__["NgModule"])({
            declarations: [
                __WEBPACK_IMPORTED_MODULE_17__app_component__["a" /* AppComponent */],
                __WEBPACK_IMPORTED_MODULE_18__remotes_remote_table_component__["a" /* RemoteTableComponent */],
                __WEBPACK_IMPORTED_MODULE_21__landing_landing_component__["a" /* LandingComponent */],
                __WEBPACK_IMPORTED_MODULE_22__subsystems_subsystems_component__["a" /* SubsystemsComponent */],
                __WEBPACK_IMPORTED_MODULE_23__remotes_remotes_component__["a" /* RemotesComponent */]
            ],
            imports: [
                __WEBPACK_IMPORTED_MODULE_0__angular_platform_browser__["BrowserModule"],
                __WEBPACK_IMPORTED_MODULE_1__angular_platform_browser_animations__["a" /* BrowserAnimationsModule */],
                __WEBPACK_IMPORTED_MODULE_3__angular_common_http__["b" /* HttpClientModule */],
                __WEBPACK_IMPORTED_MODULE_5_angular2_fontawesome_angular2_fontawesome__["Angular2FontawesomeModule"],
                __WEBPACK_IMPORTED_MODULE_9_primeng_inputtext__["InputTextModule"],
                __WEBPACK_IMPORTED_MODULE_6_primeng_primeng__["ButtonModule"],
                __WEBPACK_IMPORTED_MODULE_7_primeng_checkbox__["CheckboxModule"],
                __WEBPACK_IMPORTED_MODULE_8_primeng_confirmdialog__["ConfirmDialogModule"],
                __WEBPACK_IMPORTED_MODULE_4__angular_forms__["FormsModule"],
                __WEBPACK_IMPORTED_MODULE_10_primeng_menu__["MenuModule"],
                __WEBPACK_IMPORTED_MODULE_11_primeng_menubar__["MenubarModule"],
                __WEBPACK_IMPORTED_MODULE_12_primeng_messages__["MessagesModule"],
                __WEBPACK_IMPORTED_MODULE_14_primeng_progressspinner__["ProgressSpinnerModule"],
                __WEBPACK_IMPORTED_MODULE_15_primeng_table__["TableModule"],
                __WEBPACK_IMPORTED_MODULE_16_primeng_togglebutton__["ToggleButtonModule"],
                __WEBPACK_IMPORTED_MODULE_20__app_routing_module__["a" /* AppRoutingModule */]
            ],
            providers: [__WEBPACK_IMPORTED_MODULE_13_primeng_components_common_messageservice__["MessageService"], __WEBPACK_IMPORTED_MODULE_19__remotes_remote_service__["a" /* RemoteService */]],
            bootstrap: [__WEBPACK_IMPORTED_MODULE_17__app_component__["a" /* AppComponent */]]
        })
    ], AppModule);
    return AppModule;
}());



/***/ }),

/***/ "./src/app/landing/landing.component.css":
/***/ (function(module, exports) {

module.exports = ""

/***/ }),

/***/ "./src/app/landing/landing.component.html":
/***/ (function(module, exports) {

module.exports = "<div class=\"row justify-content-center\">\n  <div class=\"col-md-auto text-center\" style=\"padding-bottom:25px\">\n    <h1>\n      Welcome to {{ title }}!\n    </h1>\n  </div>\n</div>\n\n\n<div class=\"row justify-content-center\" style=\"padding-bottom:25px\">\n  <div class=\"col-md-auto text-center\">\n    <div *ngIf=\"displayName\">\n      <h2>Hello {{displayName}}, from PrimeNG!</h2></div>\n    <div *ngIf=\"!displayName\">\n      <h2>Hello from PrimeNG!</h2></div>\n  </div>\n</div>\n\n<div class=\"row justify-content-center\">\n  <div class=\"col-md-auto\">\n    <div class=\"ui-inputgroup\">\n      <input type=\"text\" pInputText placeholder=\"Enter your name\" [(ngModel)]=\"greet\" (change)=\"nameChanged($event)\"\n        (input)=\"input($event)\" />\n      <button pButton type=\"button\" [disabled]=\"disabled\" (click)=\"handleClick()\" icon=\"fa-check\" label=\"Greet me\"></button>\n    </div>\n  </div>\n</div>"

/***/ }),

/***/ "./src/app/landing/landing.component.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return LandingComponent; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__angular_core__ = __webpack_require__("./node_modules/@angular/core/esm5/core.js");
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};


var LandingComponent = /** @class */ (function () {
    function LandingComponent() {
        this.title = 'Janice';
        this.disabled = true;
    }
    LandingComponent.prototype.handleClick = function () {
        this.displayName = this.greet;
        this.disabled = true;
    };
    LandingComponent.prototype.nameChanged = function (_a) {
        var target = _a.target;
    };
    LandingComponent.prototype.input = function (_a) {
        var target = _a.target;
        this.disabled = (this.greet.length > 2) ? false : true;
    };
    LandingComponent.prototype.ngOnInit = function () {
        this.items = [{ label: 'Janice', styleClass: 'fancy-font' }];
    };
    __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Output"])(),
        __metadata("design:type", Object)
    ], LandingComponent.prototype, "disabled", void 0);
    __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Input"])(),
        __metadata("design:type", String)
    ], LandingComponent.prototype, "greet", void 0);
    __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Output"])(),
        __metadata("design:type", String)
    ], LandingComponent.prototype, "displayName", void 0);
    LandingComponent = __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Component"])({
            selector: 'app-landing',
            template: __webpack_require__("./src/app/landing/landing.component.html"),
            styles: [__webpack_require__("./src/app/landing/landing.component.css")]
        }),
        __metadata("design:paramtypes", [])
    ], LandingComponent);
    return LandingComponent;
}());



/***/ }),

/***/ "./src/app/remotes/remote-table.component.css":
/***/ (function(module, exports) {

module.exports = "\nth, td {\n  font-family:'Inconsolata', monospace;\n  font-size:12px;\n}\n\ninput {\n  font-family:'Inconsolata', monospace;\n  font-weight:bold;\n  font-size:12px;\n}\n\n.refresh-button {\n  width:150px;\n  font-size:12px;\n}\n\n.commit-button {\n  font-size:12px;\n}\n\n.load-spinner {\n  width:20px;\n  height:20px;\n}\n"

/***/ }),

/***/ "./src/app/remotes/remote-table.component.html":
/***/ (function(module, exports) {

module.exports = "<div class=\"row justify-content-center\">\n  <div class=\"col-md-11\">\n    <p-table [value]=\"remotes\" [scrollable]=\"true\" [loading]=\"tableLoading\" (onEditInit)=\"onEditInit($event)\"\n      (onEditCancel)=\"onEditCancel($event)\" (onEditComplete)=\"onEditComplete($event)\">\n      <ng-template pTemplate=\"header\">\n        <tr>\n          <!-- <th style=\"width: 2.25em\">Id</th> -->\n          <th style=\"width: 2.25em\">Id</th>\n          <th>Name</th>\n          <th>Host</th>\n          <th>Hardware</th>\n          <th style=\"width: 8.5em\">FW</th>\n          <th style=\"width: 8.5em\">FW Pref</th>\n          <th style=\"width: 8.5em\">At Vsn?</th>\n          <th>Started</th>\n          <th>Seen</th>\n        </tr>\n      </ng-template>\n      <ng-template pTemplate=\"body\" let-remote>\n        <tr>\n          <td style=\"width: 2.25em\">{{remote.id}}</td>\n          <td [pEditableColumn]=\"remote\" [pEditableColumnField]=\"'name'\">\n            <p-cellEditor>\n              <ng-template pTemplate=\"input\">\n                <input type=\"text\" [(ngModel)]=\"remote.name\" (blur)=\"blur({event: $event, local: $item})\">\n              </ng-template>\n              <ng-template pTemplate=\"output\">\n                {{remote.name}}\n              </ng-template>\n            </p-cellEditor>\n          </td>\n          <td>{{remote.host}}</td>\n          <td>{{remote.hardware}}</td>\n          <td style=\"width: 8.5em\">{{remote.firmware}}</td>\n          <td style=\"width: 8.5em\">{{remote.firmwarePref}}</td>\n          <td style=\"width: 8.5em\">{{remote.atVersion}}</td>\n          <td>{{remote.startedAt | date:'yyyy-MM-dd HH:mm:ss':'ET'}}</td>\n          <td>{{remote.seenAt | date:'yyyy-MM-dd HH:mm:ss':'ET'}}</td>\n        </tr>\n      </ng-template>\n    </p-table>\n  </div>\n</div>\n\n<div class=\"row justify-content-center align-items-center\" style=\"padding-top:1em\">\n  <div class=\"col-md-auto refresh-button\">\n    <p-toggleButton #refreshButton [(ngModel)]=\"autoRefresh\" onLabel=\"Refresh: On\" offLabel=\"Refresh: Off\"\n      onIcon=\"fa-check-square\" offIcon=\"fa-square\"></p-toggleButton>\n  </div>\n  <div class=\"col-md-auto commit-button\">\n    <button pButton type=\"button\" icon=\"fa-save\" [label]=\"commitLabel()\" (click)=\"handleCommit($event)\" [disabled]=\"pending.length === 0\"></button>\n  </div>\n  <div class=\"col-md-2 load-spinner\">\n    <div *ngIf=\"tableLoading\">\n      <p-progressSpinner [style]=\"{width: '10px', height: '10px'}\" strokeWidth=\"2\" fill=\"#EEEEEE\" animationDuration=\".5s\"></p-progressSpinner>\n    </div>\n  </div>\n</div>"

/***/ }),

/***/ "./src/app/remotes/remote-table.component.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return RemoteTableComponent; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__angular_core__ = __webpack_require__("./node_modules/@angular/core/esm5/core.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1_rxjs_Observable__ = __webpack_require__("./node_modules/rxjs/_esm5/Observable.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_2_rxjs_add_observable_interval__ = __webpack_require__("./node_modules/rxjs/_esm5/add/observable/interval.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_3_primeng_components_common_messageservice__ = __webpack_require__("./node_modules/primeng/components/common/messageservice.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_3_primeng_components_common_messageservice___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_3_primeng_components_common_messageservice__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_4__remote_service__ = __webpack_require__("./src/app/remotes/remote.service.ts");
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};






var RemoteTableComponent = /** @class */ (function () {
    function RemoteTableComponent(remoteService, messageService) {
        this.remoteService = remoteService;
        this.messageService = messageService;
        this.ob = __WEBPACK_IMPORTED_MODULE_1_rxjs_Observable__["a" /* Observable */].interval(3000);
        this.pending = new Array();
        this.autoRefresh = true;
        this.tableLoading = false;
        this.visible = true;
    }
    RemoteTableComponent.prototype.loadData = function () {
        var _this = this;
        this.data$ = this.remoteService.getRemotes();
        // one-time
        this.data$.subscribe(function (r) { return _this.setData(r); });
        // repeating
        this.refresh = this.ob.
            subscribe(function () { return _this.handleRefresh(); });
    };
    RemoteTableComponent.prototype.setData = function (remotes) {
        this.remotes = remotes.slice();
        this.tableLoading = false;
    };
    RemoteTableComponent.prototype.handleCommit = function (event) {
        this.pending = [];
    };
    RemoteTableComponent.prototype.handleRefresh = function () {
        var _this = this;
        if (this.autoRefresh && (document.visibilityState === 'visible')) {
            this.tableLoading = true;
            this.data$.subscribe(function (r) { return _this.setData(r); });
        }
    };
    RemoteTableComponent.prototype.ngOnDestroy = function () {
        console.log('destroy');
        this.refresh.unsubscribe();
    };
    RemoteTableComponent.prototype.ngOnInit = function () {
        // this.interval = setInterval(() => this.loadData(), 3000);
        this.loadData();
    };
    RemoteTableComponent.prototype.blur = function (_a) {
        var event = _a.event, local = _a.local;
        console.log('blur:', event, this.save, local);
    };
    RemoteTableComponent.prototype.commitLabel = function () {
        return "Changes (" + this.pending.length + ")";
    };
    RemoteTableComponent.prototype.onEditCancel = function (event) {
        var changed = event.data;
        var index = this.remotes.findIndex(function (item) { return item.id === changed.id; });
        event.data.name = this.save;
        // this.remotes[index] = this.save[index];
        this.messageService.add({ severity: 'warn', summary: 'Edit canceled', detail: 'value reverted' });
    };
    RemoteTableComponent.prototype.onEditComplete = function (event) {
        this.pending.push(event.data);
        console.log('complete:', event);
    };
    RemoteTableComponent.prototype.onEditInit = function (event) {
        this.save = event.data.name;
        this.autoRefresh = false;
        console.log('init: ', event, this.save);
    };
    __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Output"])(),
        __metadata("design:type", Object)
    ], RemoteTableComponent.prototype, "pending", void 0);
    RemoteTableComponent = __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Component"])({
            selector: 'app-remote-table',
            template: __webpack_require__("./src/app/remotes/remote-table.component.html"),
            styles: [__webpack_require__("./src/app/remotes/remote-table.component.css")]
        }),
        __metadata("design:paramtypes", [__WEBPACK_IMPORTED_MODULE_4__remote_service__["a" /* RemoteService */], __WEBPACK_IMPORTED_MODULE_3_primeng_components_common_messageservice__["MessageService"]])
    ], RemoteTableComponent);
    return RemoteTableComponent;
}());



/***/ }),

/***/ "./src/app/remotes/remote.service.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return RemoteService; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__angular_core__ = __webpack_require__("./node_modules/@angular/core/esm5/core.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1__angular_common_http__ = __webpack_require__("./node_modules/@angular/common/esm5/http.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_2_rxjs_observable_of__ = __webpack_require__("./node_modules/rxjs/_esm5/observable/of.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_3_rxjs_operators__ = __webpack_require__("./node_modules/rxjs/_esm5/operators.js");
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};




var RemoteService = /** @class */ (function () {
    function RemoteService(http) {
        this.http = http;
        this.remotesUrl = '/janice/mcp/api/remote';
        this.testRemotes = [
            {
                id: 0, name: 'lab-switches', host: 'mcr.30aea427b684', hardware: 'esp32',
                firmware: '1111111', firmwarePref: 'head', atVersion: true, startedAt: '10min',
                seenAt: '10min'
            },
            {
                id: 1, name: 'lab-sensors', host: 'mcr.30aea4287f40', hardware: 'esp32',
                firmware: '1111111', firmwarePref: 'head', atVersion: true, startedAt: '11min',
                seenAt: '11min'
            },
        ];
        this.testResponse = {
            data: [],
            data2: this.testRemotes,
            items: this.testRemotes.length,
            mtime: 1000
        };
    }
    RemoteService.prototype.getRemotes = function () {
        return this.http.get(this.remotesUrl)
            .pipe(Object(__WEBPACK_IMPORTED_MODULE_3_rxjs_operators__["b" /* map */])(function (resp) { return resp.data2; }), 
        // tap(remotes => console.log(`fetched remotes`)),
        Object(__WEBPACK_IMPORTED_MODULE_3_rxjs_operators__["a" /* catchError */])(this.handleError('getRemotes', [])));
    };
    RemoteService.prototype.handleError = function (operation, result) {
        if (operation === void 0) { operation = 'operation'; }
        return function (error) {
            // TODO: send the error to remote logging infrastructure
            console.error(error); // log to console instead
            // TODO: better job of transforming error for user consumption
            console.log(operation + " failed: " + error.message);
            // Let the app keep running by returning an empty result.
            return Object(__WEBPACK_IMPORTED_MODULE_2_rxjs_observable_of__["a" /* of */])(result);
        };
    };
    RemoteService = __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Injectable"])(),
        __metadata("design:paramtypes", [__WEBPACK_IMPORTED_MODULE_1__angular_common_http__["a" /* HttpClient */]])
    ], RemoteService);
    return RemoteService;
}());



/***/ }),

/***/ "./src/app/remotes/remotes.component.css":
/***/ (function(module, exports) {

module.exports = ""

/***/ }),

/***/ "./src/app/remotes/remotes.component.html":
/***/ (function(module, exports) {

module.exports = "<div class=\"row justify-content-center\">\n  <div class=\"col-md-auto\">\n    <h2>Subsystem</h2>\n  </div>\n</div>\n\n<div class=\"row justify-content-center\">\n  <div class=\"col-md-auto\">\n    <h3>Remotes</h3>\n  </div>\n</div>\n\n<app-remote-table></app-remote-table>\n\n<div class=\"row justify-content-center\">\n  <div class=\"col-md-7 align-self-center\">\n    <p-messages [(value)]=\"msgs\"></p-messages>\n  </div>\n</div>"

/***/ }),

/***/ "./src/app/remotes/remotes.component.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return RemotesComponent; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__angular_core__ = __webpack_require__("./node_modules/@angular/core/esm5/core.js");
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};

var RemotesComponent = /** @class */ (function () {
    function RemotesComponent() {
    }
    RemotesComponent.prototype.ngOnInit = function () {
    };
    RemotesComponent = __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Component"])({
            selector: 'app-remotes',
            template: __webpack_require__("./src/app/remotes/remotes.component.html"),
            styles: [__webpack_require__("./src/app/remotes/remotes.component.css")]
        }),
        __metadata("design:paramtypes", [])
    ], RemotesComponent);
    return RemotesComponent;
}());



/***/ }),

/***/ "./src/app/subsystems/subsystems.component.css":
/***/ (function(module, exports) {

module.exports = ""

/***/ }),

/***/ "./src/app/subsystems/subsystems.component.html":
/***/ (function(module, exports) {

module.exports = "<p>\n  subsystems works!\n</p>\n"

/***/ }),

/***/ "./src/app/subsystems/subsystems.component.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return SubsystemsComponent; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__angular_core__ = __webpack_require__("./node_modules/@angular/core/esm5/core.js");
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};

var SubsystemsComponent = /** @class */ (function () {
    function SubsystemsComponent() {
    }
    SubsystemsComponent.prototype.ngOnInit = function () {
    };
    SubsystemsComponent = __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Component"])({
            selector: 'app-subsystems',
            template: __webpack_require__("./src/app/subsystems/subsystems.component.html"),
            styles: [__webpack_require__("./src/app/subsystems/subsystems.component.css")]
        }),
        __metadata("design:paramtypes", [])
    ], SubsystemsComponent);
    return SubsystemsComponent;
}());



/***/ }),

/***/ "./src/environments/environment.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return environment; });
// The file contents for the current environment will overwrite these during build.
// The build system defaults to the dev environment which uses `environment.ts`, but if you do
// `ng build --env=prod` then `environment.prod.ts` will be used instead.
// The list of which env maps to which file can be found in `.angular-cli.json`.
var environment = {
    production: false
};


/***/ }),

/***/ "./src/main.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
Object.defineProperty(__webpack_exports__, "__esModule", { value: true });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__angular_core__ = __webpack_require__("./node_modules/@angular/core/esm5/core.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1__angular_platform_browser_dynamic__ = __webpack_require__("./node_modules/@angular/platform-browser-dynamic/esm5/platform-browser-dynamic.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_2__app_app_module__ = __webpack_require__("./src/app/app.module.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_3__environments_environment__ = __webpack_require__("./src/environments/environment.ts");




if (__WEBPACK_IMPORTED_MODULE_3__environments_environment__["a" /* environment */].production) {
    Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["enableProdMode"])();
}
Object(__WEBPACK_IMPORTED_MODULE_1__angular_platform_browser_dynamic__["a" /* platformBrowserDynamic */])().bootstrapModule(__WEBPACK_IMPORTED_MODULE_2__app_app_module__["a" /* AppModule */])
    .catch(function (err) { return console.log(err); });


/***/ }),

/***/ 0:
/***/ (function(module, exports, __webpack_require__) {

module.exports = __webpack_require__("./src/main.ts");


/***/ })

},[0]);
//# sourceMappingURL=main.bundle.js.map