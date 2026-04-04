'use strict';

const libQ = require('kew');
const fs = require('fs-extra');
const Gpio = require('onoff').Gpio;

// ============================================================
// GPIO НАСТРОЙКИ (BCM нумерация)
// ============================================================
const GPIO_CLOCK_GRID = 6;   // Pin 31 — переключение генераторов
                              // LOW  = 44.1kHz сетка (22.579MHz)
                              // HIGH = 48kHz сетка (24.576MHz)

const GPIO_OCKS0 = 5;        // Pin 29 — AK4113 OCKS0
const GPIO_OCKS1 = 13;       // Pin 33 — AK4113 OCKS1
// ============================================================

// OCKS таблица (AK4113 datasheet, Table 2, parallel mode):
// OCKS1=0, OCKS0=0 -> 256fs, max 108kHz  (для <=96kHz)
// OCKS1=1, OCKS0=1 -> 128fs, max 216kHz  (для 176.4/192kHz)

const SAMPLERATES_44   = [44100, 88200, 176400];
const SAMPLERATES_48   = [48000, 96000, 192000];
const SAMPLERATES_HIGH = [176400, 192000];

module.exports = DDPlayerPlugin;

function DDPlayerPlugin(context) {
  this.context = context;
  this.commandRouter = context.coreCommand;
  this.logger = context.logger;
  this.configManager = context.configManager;
  this.gpioClockGrid = null;
  this.gpioOcks0 = null;
  this.gpioOcks1 = null;
}

DDPlayerPlugin.prototype.onVolumioStart = function() {
  const defer = libQ.defer();
  defer.resolve();
  return defer.promise;
};

DDPlayerPlugin.prototype.onStart = function() {
  const defer = libQ.defer();
  const self = this;

  self.logger.info('[DDPlayer] Starting plugin...');

  try {
    self.gpioClockGrid = new Gpio(GPIO_CLOCK_GRID, 'out');
    self.gpioOcks0     = new Gpio(GPIO_OCKS0, 'out');
    self.gpioOcks1     = new Gpio(GPIO_OCKS1, 'out');

    self.gpioClockGrid.writeSync(0);
    self.gpioOcks0.writeSync(0);
    self.gpioOcks1.writeSync(0);

    self.logger.info('[DDPlayer] GPIO initialized: GRID=LOW(44.1k), OCKS=00');
  } catch (e) {
    self.logger.error('[DDPlayer] GPIO init error: ' + e.message);
  }

  if (self.commandRouter.system_events) {
    self.commandRouter.system_events.on('samplerate', self.onSamplerateChange.bind(self));
  }

  defer.resolve();
  return defer.promise;
};

DDPlayerPlugin.prototype.onStop = function() {
  const defer = libQ.defer();
  const self = this;

  self.logger.info('[DDPlayer] Stopping plugin...');

  [self.gpioClockGrid, self.gpioOcks0, self.gpioOcks1].forEach(function(g) {
    if (g) { g.writeSync(0); g.unexport(); }
  });

  self.gpioClockGrid = null;
  self.gpioOcks0 = null;
  self.gpioOcks1 = null;

  defer.resolve();
  return defer.promise;
};

DDPlayerPlugin.prototype.onSamplerateChange = function(samplerate) {
  const self = this;
  const rate = parseInt(samplerate, 10);

  self.logger.info('[DDPlayer] Samplerate: ' + rate + ' Hz');

  if (SAMPLERATES_44.includes(rate)) {
    self.setGridPin(0);
  } else if (SAMPLERATES_48.includes(rate)) {
    self.setGridPin(1);
  } else {
    self.logger.warn('[DDPlayer] Unknown samplerate ' + rate + ', defaulting to 44.1kHz');
    self.setGridPin(0);
  }

  self.setOcks(
    SAMPLERATES_HIGH.includes(rate) ? 1 : 0,
    SAMPLERATES_HIGH.includes(rate) ? 1 : 0
  );
};

DDPlayerPlugin.prototype.setGridPin = function(value) {
  const self = this;
  if (self.gpioClockGrid) {
    self.gpioClockGrid.writeSync(value);
    self.logger.info('[DDPlayer] GRID = ' + (value ? 'HIGH(48k)' : 'LOW(44.1k)'));
  }
};

DDPlayerPlugin.prototype.setOcks = function(ocks1, ocks0) {
  const self = this;
  if (self.gpioOcks0 && self.gpioOcks1) {
    self.gpioOcks1.writeSync(ocks1);
    self.gpioOcks0.writeSync(ocks0);
    self.logger.info('[DDPlayer] OCKS1=' + ocks1 + ' OCKS0=' + ocks0);
  }
};

DDPlayerPlugin.prototype.getUIConfig = function() {
  const defer = libQ.defer();
  defer.resolve({
    page: { title: 'DDPlayer' },
    sections: [{
      title: 'GPIO Info',
      content: [
        { element: 'label', label: 'Clock Grid: BCM 6 (Pin 31)' },
        { element: 'label', label: 'AK4113 OCKS0: BCM 5 (Pin 29)' },
        { element: 'label', label: 'AK4113 OCKS1: BCM 13 (Pin 33)' },
      ]
    }]
  });
  return defer.promise;
};

DDPlayerPlugin.prototype.getConfigurationFiles = function() {
  return ['config.json'];
};
