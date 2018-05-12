// exports.config = {    See http://brunch.io/#documentation for docs.

exports.files = {
  javascripts: {
    joinTo: 'js/app.js',
    // {}
    // "js/app.js": /^(js)/,
    // "js/vendor.js": /^(vendor|deps|node_modules).*/
    // }

    // To use a separate vendor.js bundle, specify two files path
    // https://github.com/brunch/brunch/blob/master/docs/config.md#files
    // joinTo: {  "js/app.js": /^(js)/,  "js/vendor.js": /^(vendor)|(deps)/ }
    //
    // To change the order of concatenation of files, explicitly mention here
    // https://github.com/brunch/brunch/tree/master/docs#concatenation order: {
    // before: [     "vendor/js/jquery-2.1.1.js", "vendor/js/bootstrap.min.js"
    // ] }
  },
  stylesheets: {
    joinTo: 'css/app.css',
    // concat app.css last
    order: {
      after: ['priv/static/css/app.scss'],
    },
  },
  // templates: {joinTo: "js/app.js"}
};

exports.conventions = {
  // This option sets where we should place non-css and non-js assets in. By
  // default, we set this to "/assets/static". Files in this directory will
  // be copied to `paths.public`, which is "priv/static" by default.
  assets: [/^(static)/],
  // assets: [/^(static)/, /bundles\//],
  ignored: [path => path.includes('bundles')],
};

// Phoenix paths configuration
exports.paths = {
  // Dependencies and current project directories to watch
  watched: [
    'static', 'css', 'js', 'vendor',
  ],
  // Where to compile files to
  public: '../priv/static',
};

// Configure your plugins
exports.plugins = {
  babel: {
    presets: ['latest', 'stage-0'],
    ignore: [/bundles/],
    // Do not use ES6 compiler in vendor code ignore: [ /vendor/ ]
  },
  pleeease: {
    sass: true,
    autoprefixer: {
      browsers: ['> 1%'],
    },
  },
  copycat: {
    images: [
      'static/images', 'node_modules/datatables.net-dt/images',
    ],
    bundles: [
       'angular/dist',
    ],
    // bundles: [
    //   'angular/dist',
    // ],
    onlyChanged: true,
    verbose: true,
  },
  sass: {
    options: {
      // tell sass-brunch where to look for files to @import
      includePaths: ['node_modules/bootstrap/scss',
        'node_modules/datatables.net-dt/css',
        'node_modules/datatables.net-buttons-dt/css',
        'node_modules/datatables.net-scroller-dt/css',
        'node_modules/datatables.net-select-dt/css',
      ],
      // minimum precision required by bootstrap
      precision: 8,
    },
  },
};

exports.modules = {
  autoRequire: {
    'js/app.js': ['js/app'],
  },
};

exports.npm = {
  enabled: true,
  debug: true,
  // Bootstrap JavaScript requires both '$', 'jQuery', and Tether in global
  // scope
  globals: {
    $: 'jquery',
    jQuery: 'jquery',
    Tether: 'tether',
    Popper: 'popper.js',
    bootstrap: 'bootstrap',
    dt: 'datatables.net',
    buttons: 'datatables.net-buttons',
    prettyMs: 'pretty-ms',
  },
};
