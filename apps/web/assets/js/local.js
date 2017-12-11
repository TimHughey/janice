function pageReady( jQuery ) {
    // Code to run when the document is ready.
}

function pageFullyLoaded() {
  setTimeout(function(){
        var masthead = $('#mastheadText');
        masthead.removeClass('text-muted').addClass('text-ready');
    }, 1000);

}

$( window ).on( "load", pageFullyLoaded );

// $(function() {
//     $('.lazy').Lazy({
//       noDeviceTabLoad: function(element) {
//           var data = $.get("mcp/detail/nodevice");
//           element.html(data);
//         }});
//     });

$( "#collapseNoDevice" ).on('show.bs.collapse', function(event) {
  // alert("clicked!");
    jQuery.get( "detail/nodevice", function( data ) {
      $( "#noDeviceTable" ).html( data ); });

      setTimeout(function(){ $('#collapseNoDevice').collapse('hide'); }, 3000);
});

$( "#collapseSwitches" ).on('show.bs.collapse', function(event) {
  // alert("clicked!");
    jQuery.get( "detail/switches", function( data ) {
      $( "#switchesTable" ).html( data ); });
});

$( "#collapseSensors" ).on('show.bs.collapse', function(event) {
  // alert("clicked!");
    jQuery.get( "detail/sensors", function( data ) {
      $( "#sensorsTable" ).html( data ); });
});

//
//   jQuery.get( "mcp/detail/nodevice", function( data ) {
//     $( "#noDeviceCard" ).html( data );
//   });
// });
