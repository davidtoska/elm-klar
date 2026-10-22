// Which icons the themed icon modules (Klar.Icon.*) contain: the names are Lucide
// names. The generator (generate-icons.mjs) turns this list into Elm modules.
// Only the first `limit` names of a group are generated; the names after them are
// a reserve (move the limit up to take them in). To add an icon: add its name to
// a group here and run the generator.

export const groups = [
  {
    module: 'Arrows',
    limit: 20,
    title: 'Arrows and movement',
    names: `arrow-up-left arrow-down-left arrow-big-up arrow-big-down arrow-big-left arrow-big-right
      arrow-up-from-line arrow-down-to-line arrow-left-to-line arrow-right-to-line
      corner-down-left corner-down-right corner-up-left corner-up-right corner-left-down corner-right-down
      circle-arrow-up circle-arrow-down circle-arrow-left circle-arrow-right
      square-arrow-out-up-right undo-2 redo-2 repeat repeat-1 shuffle refresh-ccw rotate-cw rotate-ccw
      merge split move-horizontal move-vertical chevrons-left-right arrow-right-left arrow-down-up trending-up-down`,
  },
  {
    module: 'Business',
    limit: 22,
    title: 'Business and finance',
    names: `wallet banknote coins piggy-bank landmark receipt-text receipt-cent badge-dollar-sign badge-percent
      euro pound-sterling japanese-yen bitcoin hand-coins handshake ticket ticket-percent store factory scale gavel
      briefcase-business presentation target award trophy medal signature stamp contact id-card wallet-cards
      crown gem circle-dollar-sign circle-percent shopping-basket tags`,
  },
  {
    module: 'Calendar',
    limit: 12,
    title: 'Calendar and time',
    names: `alarm-clock alarm-clock-check timer timer-reset calendar-days calendar-plus calendar-minus calendar-x
      calendar-clock calendar-range calendar-search calendar-sync clock-alert clock-arrow-up clock-check clock-plus
      watch sunrise sunset`,
  },
  {
    module: 'Communication',
    limit: 20,
    title: 'Communication',
    names: `mail-open mail-check mail-plus mail-minus mail-x mail-search mail-warning mails mailbox message-circle
      message-circle-more message-circle-warning message-square-text message-square-more message-square-plus
      message-square-reply message-square-quote messages-square send-horizontal phone-call phone-incoming
      phone-outgoing phone-missed phone-off phone-forwarded voicemail megaphone megaphone-off rss share-2
      reply-all contact-round speech captions languages`,
  },
  {
    module: 'Data',
    limit: 28,
    title: 'Data and charts',
    names: `database-backup database-zap database-search database-plus database-minus database-check database-x
      chart-bar chart-line chart-area chart-scatter chart-column chart-candlestick chart-gantt chart-network
      chart-spline chart-no-axes-column chart-column-increasing chart-column-decreasing chart-bar-stacked
      gauge variable binary regex funnel-plus funnel-x list-filter table-properties table-2 kanban
      square-kanban timeline workflow waypoints network sheet scan-barcode qr-code columns-3 rows-3 grid-3x3
      diff equal divide infinity radical omega lambda square-function decimals-arrow-right ratio blend`,
  },
  {
    module: 'Developer',
    limit: 16,
    title: 'Developer tools',
    names: `git-merge git-pull-request git-fork git-compare git-graph git-branch-plus git-commit-horizontal
      bug bug-off webhook container cpu microchip brackets code-xml file-code square-terminal blocks puzzle
      component boxes circuit-board server-cog server-crash hard-drive-download hard-drive-upload bot brain-circuit
      sparkles wand-sparkles rocket`,
  },
  {
    module: 'Devices',
    limit: 20,
    title: 'Devices and hardware',
    names: `laptop tablet tv printer router usb battery-full battery-charging battery-low bluetooth headphones mic
      mic-off speaker webcam mouse gamepad-2 watch plug power-off signal radio satellite-dish ethernet-port
      monitor-smartphone monitor-off smartphone-charging server-off cast airplay scan-line nfc disc cable
      radio-tower antenna`,
  },
  {
    module: 'Documents',
    limit: 34,
    title: 'Files, folders and documents',
    names: `file-check file-x file-up file-down file-search file-lock file-key file-clock file-chart-column
      file-chart-pie file-image file-video-camera file-music file-archive file-stack file-pen file-user
      file-braces file-terminal file-type file-sliders file-digit file-scan files folder-check folder-down
      folder-up folder-lock folder-search folder-tree folder-cog folder-archive folder-closed folder-git
      folder-input folder-output folder-clock folder-kanban folder-users folder-user folder-x folder-minus
      folder-sync folders book-open book-open-text book-bookmark book-check book-user library notebook
      notebook-pen notebook-text scroll scroll-text newspaper sticky-note clipboard-list clipboard-copy
      clipboard-paste clipboard-pen clipboard-clock clipboard-x clipboard-plus notepad-text`,
  },
  {
    module: 'Editor',
    limit: 22,
    title: 'Text editing',
    names: `heading-1 heading-2 heading-3 text-align-justify list-checks list-todo list-plus list-minus list-x
      list-collapse list-indent-increase list-indent-decrease list-start list-end list-restart pilcrow text-quote
      quote subscript superscript baseline highlighter eraser pen-line pencil-line paint-bucket palette pipette
      case-sensitive case-upper case-lower letter-spacing line-height whole-word spell-check remove-formatting
      table-cells-merge table-cells-split text-cursor text-cursor-input text-search text-wrap replace replace-all`,
  },
  {
    module: 'Interface',
    limit: 32,
    title: 'Interface and controls',
    names: `panel-left panel-right panel-top panel-bottom panel-left-close panel-left-open panel-right-close
      panel-right-open layout-grid layout-list layout-panel-left layout-panel-top layout-template grid-2x2
      square-dashed square-stack sliders-horizontal sliders-vertical settings-2 cog maximize-2 minimize-2
      expand shrink fullscreen fold-vertical unfold-vertical fold-horizontal unfold-horizontal focus crosshair
      locate locate-fixed mouse-pointer mouse-pointer-click pointer hand lasso-select eye-closed lock-open
      lock-keyhole key-round fingerprint-pattern shield-alert shield-ban shield-x shield-off shield-question-mark
      bell-ring bell-off bell-plus bell-dot bookmark-check bookmark-plus star-half star-off thumbs-up
      thumbs-down circle-check-big circle-alert circle-question-mark circle-dot circle-dashed circle-slash
      circle-off circle-stop circle-pause circle-play octagon-x octagon-minus triangle-alert badge-alert
      badge-info badge-x badge-minus badge-plus`,
  },
  {
    module: 'Logistics',
    limit: 26,
    title: 'Logistics, transport and places',
    names: `truck-electric forklift package-open package-check package-plus package-minus package-x
      package-search boxes ship ship-wheel plane plane-takeoff plane-landing bus train-front tram-front car
      car-front bike motorbike van route map-plus map-minus map-pinned map-pin-check map-pin-plus map-pin-minus
      map-pin-off map-pin-house navigation navigation-2 compass signpost milestone door-open door-closed house
      house-plus hotel hospital school church university building-complex fuel ev-charger circle-parking
      traffic-cone construction anchor luggage baggage-claim earth radar`,
  },
  {
    module: 'Media',
    limit: 14,
    title: 'Media and sound',
    names: `skip-back skip-forward step-back step-forward rewind fast-forward volume-1 volume-2 volume-x volume-off
      video video-off camera-off image-plus image-off images film music clapperboard audio-lines audio-waveform
      repeat-2 disc-3 mic-vocal headset tv-minimal-play picture-in-picture screen-share projector`,
  },
  {
    module: 'Nature',
    limit: 16,
    title: 'Nature, weather and animals',
    names: `sun-medium sun-dim moon-star cloud-sun cloud-rain cloud-snow cloud-lightning cloud-fog cloud-drizzle
      cloudy snowflake wind droplet droplets flame thermometer umbrella rainbow waves-horizontal leaf sprout
      trees tree-pine tree-deciduous flower mountain bird cat dog fish squirrel rabbit turtle shell wheat
      leafy-green apple cherry carrot banana grape`,
  },
  {
    module: 'People',
    limit: 16,
    title: 'People and expressions',
    names: `user-round user-round-check user-round-plus user-round-minus user-round-x user-round-cog
      user-round-search user-cog user-lock user-minus user-pen user-search user-star user-shield users-round
      id-card-lanyard baby accessibility person-standing hand-helping hand-heart face-grinning face-neutral
      face-slightly-frowning face-slightly-smiling face-angry face-expressionless graduation-cap hard-hat
      glasses shirt footprints`,
  },
  {
    module: 'Science',
    limit: 16,
    title: 'Science, health and everyday objects',
    names: `hammer drill ruler pencil-ruler paintbrush-vertical brush magnet microscope test-tube atom dna beaker
      stethoscope pill syringe heart-pulse bandage ambulance coffee utensils pizza wine beer gift cake
      party-popper flashlight lightbulb-off lamp plug-zap toolbox archive-restore recycle shredder vault
      key-square bomb skull ghost dices swords`,
  },
].map((g) => {
  const all = g.names.split(/\s+/).filter(Boolean);
  return { ...g, names: all.slice(0, g.limit), reserve: all.slice(g.limit) };
});
