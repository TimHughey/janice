import {
  prettySeconds,
  prettyUs,
  displayStatus,
  autoRefresh,
}
  from './merc_util';

function columns() {
  return [{
    data: 'id',
    class: 'col-center',
  }, {
    data: 'name',
  }, {
    data: 'device',
  }, {
    data: 'description',
  },
  {
    data: 'dev_latency',
    class: 'col-center',
    render: prettyUs,
  }, {
    data: 'last_seen_secs',
    class: 'col-center',
    render: prettySeconds,
  }, {
    data: 'reading_secs',
    class: 'col-center',
    render: prettySeconds,
  }, {
    data: 'celsius',
    class: 'col-center',
  },
  ];
}

function create() {
  const sensorTable = jQuery('#sensorsTable').DataTable({
    dom: 'Bfrtip',
    ajax: 'mcp/api/sensor',
    scrollY: '50vh',
    // deferRender: true,
    scroller: true,
    select: {
      style: 'single',
      items: 'row',
      // selector: 'td:nth-child(1)', // only allow devices to be selected
    },
    order: [
      [1, 'asc'],
    ],
    columns: columns(),
    columnDefs: [
      {
        targets: [0],
        visible: false,
        searchable: false,
      },
    ],
    buttons: [{
      text: 'Refresh',
      attr: {
        id: 'sensorRefreshButton',
      },
      action(e, dt, node, config) {
        if (sensorTable.button(0).active()) {
          sensorTable.button(0).active(false);
        } else {
          sensorTable.button(0).active(true);
          autoRefresh();
        }
      },
    },
    {
      text: 'Rename',
      extend: 'selected',
      attr: {
        id: 'sensorRenameButton',
      },
      action(e, dt, node, config) {
        const {
          name,
          id,
        } = sensorTable.rows({
          selected: true,
        }).data()[0];

        const newName = jQuery('#generalInputBox').val();

        sensorTable.button(1).processing(true);
        jQuery.ajax({
          url: `mcp/api/sensor/${id}`,
          type: 'PATCH',
          data: {
            name: newName,
          },
          dateType: 'json',
          beforeSend(xhr) {
            // send the CSRF token included as a meta on the HTML page
            const token = jQuery("meta[name='csrf-token']").attr('content');
            xhr.setRequestHeader('X-CSRF-Token', token);
          },
          error(xhr, status, error) {
            console.log('error xhr:', xhr);
            displayStatus(`Error changing name of ${name}`);
          },
          success(data, status, jqXHR) {
            console.log(data, status, jqXHR);
            displayStatus(`Sensor name changed to ${data.name}`);
            // const response = jqXHR.responseJSON();
            // displayStatus(`Sensor name changed to ${response}`);
          },
          complete(xhr, status) {
            sensorTable.ajax.reload(null, false);
            sensorTable.button(1).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
            sensorTable.button(0).active(true);
          },
        });
      },
    }, {
      text: 'Delete',
      extend: 'selected',
      attr: {
        id: 'sensorDeleteButton',
      },
      action(e, dt, node, config) {
        const {
          name,
          id,
        } = sensorTable.rows({
          selected: true,
        }).data()[0];

        sensorTable.button(2).processing(true);
        jQuery.ajax({
          url: `mcp/api/sensor/${id}`,
          type: 'DELETE',
          beforeSend(xhr) {
            // send the CSRF token included as a meta on the HTML page
            const token = jQuery("meta[name='csrf-token']").attr('content');
            xhr.setRequestHeader('X-CSRF-Token', token);
          },
          error(xhr, status, error) {
            console.log('error xhr:', xhr);
            displayStatus(`Error deleting ${name}`);
          },
          success(xhr, status) {
            displayStatus(`Deleted sensor ${name}`);
          },
          complete(xhr, status) {
            sensorTable.ajax.reload(null, false);
            sensorTable.button(2).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
            sensorTable.button(0).active(true);
          },
        });
      },
    },
    ],
  });

  sensorTable.on('select', (e, dt, type, indexes) => {
    sensorTable.button(0).active(false);

    const inputBox = jQuery('#generalPurposeForm');

    jQuery('#generalInputBox').attr(
      'placeholder',
      'Enter new sensor name here then press Rename',
    );
    inputBox.fadeIn('fast');
  });

  sensorTable.on('deselect', (e, dt, type, indexes) => {
    const inputBox = jQuery('#generalPurposeForm');
    sensorTable.button(0).active(true);

    inputBox.fadeOut('fast');
  });

  sensorTable.button(0).active(true);
}

export default {
  create,
};
