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
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_3__angular_forms__ = __webpack_require__("./node_modules/@angular/forms/esm5/forms.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_4_angular2_fontawesome_angular2_fontawesome__ = __webpack_require__("./node_modules/angular2-fontawesome/angular2-fontawesome.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_4_angular2_fontawesome_angular2_fontawesome___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_4_angular2_fontawesome_angular2_fontawesome__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_5_primeng_primeng__ = __webpack_require__("./node_modules/primeng/primeng.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_5_primeng_primeng___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_5_primeng_primeng__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_6_primeng_confirmdialog__ = __webpack_require__("./node_modules/primeng/confirmdialog.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_6_primeng_confirmdialog___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_6_primeng_confirmdialog__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_7_primeng_inputtext__ = __webpack_require__("./node_modules/primeng/inputtext.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_7_primeng_inputtext___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_7_primeng_inputtext__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_8_primeng_menu__ = __webpack_require__("./node_modules/primeng/menu.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_8_primeng_menu___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_8_primeng_menu__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_9_primeng_menubar__ = __webpack_require__("./node_modules/primeng/menubar.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_9_primeng_menubar___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_9_primeng_menubar__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_10_primeng_table__ = __webpack_require__("./node_modules/primeng/table.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_10_primeng_table___default = __webpack_require__.n(__WEBPACK_IMPORTED_MODULE_10_primeng_table__);
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_11__app_component__ = __webpack_require__("./src/app/app.component.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_12__remotes_remote_table_component__ = __webpack_require__("./src/app/remotes/remote-table.component.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_13__remotes_remote_service__ = __webpack_require__("./src/app/remotes/remote.service.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_14__app_routing_module__ = __webpack_require__("./src/app/app-routing.module.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_15__landing_landing_component__ = __webpack_require__("./src/app/landing/landing.component.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_16__subsystems_subsystems_component__ = __webpack_require__("./src/app/subsystems/subsystems.component.ts");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_17__remotes_remotes_component__ = __webpack_require__("./src/app/remotes/remotes.component.ts");
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
                __WEBPACK_IMPORTED_MODULE_11__app_component__["a" /* AppComponent */],
                __WEBPACK_IMPORTED_MODULE_12__remotes_remote_table_component__["a" /* RemoteTableComponent */],
                __WEBPACK_IMPORTED_MODULE_15__landing_landing_component__["a" /* LandingComponent */],
                __WEBPACK_IMPORTED_MODULE_16__subsystems_subsystems_component__["a" /* SubsystemsComponent */],
                __WEBPACK_IMPORTED_MODULE_17__remotes_remotes_component__["a" /* RemotesComponent */]
            ],
            imports: [
                __WEBPACK_IMPORTED_MODULE_0__angular_platform_browser__["BrowserModule"],
                __WEBPACK_IMPORTED_MODULE_1__angular_platform_browser_animations__["a" /* BrowserAnimationsModule */],
                __WEBPACK_IMPORTED_MODULE_4_angular2_fontawesome_angular2_fontawesome__["Angular2FontawesomeModule"],
                __WEBPACK_IMPORTED_MODULE_7_primeng_inputtext__["InputTextModule"],
                __WEBPACK_IMPORTED_MODULE_5_primeng_primeng__["ButtonModule"],
                __WEBPACK_IMPORTED_MODULE_6_primeng_confirmdialog__["ConfirmDialogModule"],
                __WEBPACK_IMPORTED_MODULE_3__angular_forms__["FormsModule"],
                __WEBPACK_IMPORTED_MODULE_8_primeng_menu__["MenuModule"],
                __WEBPACK_IMPORTED_MODULE_9_primeng_menubar__["MenubarModule"],
                __WEBPACK_IMPORTED_MODULE_10_primeng_table__["TableModule"],
                __WEBPACK_IMPORTED_MODULE_14__app_routing_module__["a" /* AppRoutingModule */]
            ],
            providers: [__WEBPACK_IMPORTED_MODULE_13__remotes_remote_service__["a" /* RemoteService */]],
            bootstrap: [__WEBPACK_IMPORTED_MODULE_11__app_component__["a" /* AppComponent */]]
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

module.exports = "\nth, td {\n  font-family:'Inconsolata', monospace !important;\n  font-size:12px;\n}\n\ninput {\n  font-family:'Inconsolata', monospace !important;\n  font-weight:bold;\n  font-size:12px;\n}\n"

/***/ }),

/***/ "./src/app/remotes/remote-table.component.html":
/***/ (function(module, exports) {

module.exports = "<p-table [value]=\"remotes\" [scrollable]=\"true\" (onEditInit)=\"onEditInit($event)\" (onEditCancel)=\"onEditCancel($event)\"\n  (onEditComplete)=\"onEditComplete($event)\">\n  <ng-template pTemplate=\"header\">\n    <tr>\n      <!-- <th style=\"width: 2.25em\">Id</th> -->\n      <th style=\"width: 2.25em\">Id</th>\n      <th>Name</th>\n      <th>Host</th>\n      <th>Hardware</th>\n      <th>FW</th>\n      <th>FW Pref</th>\n      <th>At Vsn?</th>\n      <th>Started</th>\n      <th>Seen</th>\n    </tr>\n  </ng-template>\n  <ng-template pTemplate=\"body\" let-remote>\n    <tr>\n      <td style=\"width: 2.25em\">{{remote.id}}</td>\n      <td [pEditableColumn]=\"remote\" [pEditableColumnField]=\"'name'\">\n        <p-cellEditor>\n          <ng-template pTemplate=\"input\">\n            <input type=\"text\" [(ngModel)]=\"remote.name\" (blur)=\"blur({event: $event, local: $item})\">\n          </ng-template>\n          <ng-template pTemplate=\"output\">\n            {{remote.name}}\n          </ng-template>\n        </p-cellEditor>\n      </td>\n      <td>{{remote.host}}</td>\n      <td>{{remote.hardware}}</td>\n      <td>{{remote.firmware}}</td>\n      <td>{{remote.firmwarePref}}</td>\n      <td>{{remote.atVersion}}</td>\n      <td>{{remote.startedAt}}</td>\n      <td>{{remote.seenAt}}</td>\n    </tr>\n  </ng-template>\n</p-table>\n\n<div class=\"row justify-content-center\">\n  <div class=\"col-md-auto\">\n    Pending Commands: {{ pending.length }}\n  </div>\n</div>"

/***/ }),

/***/ "./src/app/remotes/remote-table.component.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return RemoteTableComponent; });
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_0__angular_core__ = __webpack_require__("./node_modules/@angular/core/esm5/core.js");
/* harmony import */ var __WEBPACK_IMPORTED_MODULE_1__remote_service__ = __webpack_require__("./src/app/remotes/remote.service.ts");
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
    function RemoteTableComponent(remoteService) {
        this.remoteService = remoteService;
        this.pending = new Array();
    }
    RemoteTableComponent.prototype.ngOnInit = function () {
        this.remotes = this.remoteService.getRemotes();
        // this.remoteService.getRemotes().then(remotes => this.remotes = remotes);
    };
    RemoteTableComponent.prototype.blur = function (_a) {
        var event = _a.event, local = _a.local;
        console.log('blur:', event, this.save, local);
    };
    RemoteTableComponent.prototype.onEditCancel = function (event) {
        var changed = event.data;
        var index = this.remotes.findIndex(function (item) { return item.id === changed.id; });
        event.data.name = this.save;
        // this.remotes[index] = this.save[index];
        console.log('cancel:', event, index);
    };
    RemoteTableComponent.prototype.onEditComplete = function (event) {
        this.pending.push(event.data);
        console.log('complete:', event);
    };
    RemoteTableComponent.prototype.onEditInit = function (event) {
        this.save = event.data.name;
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
        __metadata("design:paramtypes", [__WEBPACK_IMPORTED_MODULE_1__remote_service__["a" /* RemoteService */]])
    ], RemoteTableComponent);
    return RemoteTableComponent;
}());



/***/ }),

/***/ "./src/app/remotes/remote.service.ts":
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "a", function() { return RemoteService; });
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

var RemoteService = /** @class */ (function () {
    function RemoteService() {
        this.remotes = [
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
    }
    RemoteService.prototype.getRemotes = function () {
        return this.remotes;
    };
    RemoteService = __decorate([
        Object(__WEBPACK_IMPORTED_MODULE_0__angular_core__["Injectable"])(),
        __metadata("design:paramtypes", [])
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

module.exports = "<div class=\"row justify-content-center\">\n  <div class=\"col-md-auto\">\n    <h2>Subsystem</h2>\n  </div>\n</div>\n\n<div class=\"row justify-content-center\">\n  <div class=\"col-md-auto\">\n    <h3>Remotes</h3>\n  </div>\n</div>\n\n<div class=\"row justify-content-center\">\n  <div class=\"col-md-11\">\n    <app-remote-table></app-remote-table>\n  </div>\n</div>"

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