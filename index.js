'use strict';

const libQ = require('kew');
const fs = require('fs-extra');

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

// ============================================================
// GPIO через sysfs — без нативных модулей
// ============================================================

function gpioExport(pin) {
  try {
    if (!fs.existsSync('/sys/class/gpio/gpio' + pin)) {
      fs.writeFileSync('/sys/class/gpio/export', String(pin));
    }
    fs.writeFileSync('/sys/class/gpio/gpio' + pin + '/direction', 'out');
  } catch(e) {}
}

function gpioWrite(pin, value) {
  try {
    fs.writeFileSync('/sys/class/gpio/gpio' + pin + '/value', String(value));
  } catch(e) {}
}

function gpioUnexport(pin) {
  try {
    fs.writeFileSync('/sys/class/gpio/unexport', String(pin));
  } catch(e) {}
}

// ============================================================

module.exports = DDPlayerPlugin;

function DDPlayerPlugin(context) {
  this.context = context;
  this.commandRouter = context.coreCommand;
  this.logger = context.logger;
  this.configManager = context.configManager;
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

  // Инициализируем GPIO
  [GPIO_CLOCK_GRID, GPIO_OCKS0, GPIO_OCKS1].forEach(function(pin) {
    gpioExport(pin);
    gpioWrite(pin, 0);
  });

  self.logger.info('[DDPlayer] GPIO initialized: GRID=LOW(44.1k), OCKS=00');

  // Подписываемся на смену samplerate
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

  // Возвращаем GPIO в LOW и освобождаем
  [GPIO_CLOCK_GRID, GPIO_OCKS0, GPIO_OCKS1].forEach(function(pin) {
    gpioWrite(pin, 0);
    gpioUnexport(pin);
  });

  defer.resolve();
  return defer.promise;
};

DDPlayerPlugin.prototype.onSamplerateChange = function(samplerate) {
  const self = this;
  const rate = parseInt(samplerate, 10);

  self.logger.info('[DDPlayer] Samplerate: ' + rate + ' Hz');

  // Переключаем сетку генератора
  if (SAMPLERATES_44.includes(rate)) {
    gpioWrite(GPIO_CLOCK_GRID, 0);
    self.logger.info('[DDPlayer] GRID = LOW (44.1kHz)');
  } else if (SAMPLERATES_48.includes(rate)) {
    gpioWrite(GPIO_CLOCK_GRID, 1);
    self.logger.info('[DDPlayer] GRID = HIGH (48kHz)');
  } else {
    self.logger.warn('[DDPlayer] Unknown samplerate ' + rate + ', defaulting to 44.1kHz');
    gpioWrite(GPIO_CLOCK_GRID, 0);
  }

  // Переключаем OCKS на AK4113
  if (SAMPLERATES_HIGH.includes(rate)) {
    gpioWrite(GPIO_OCKS1, 1);
    gpioWrite(GPIO_OCKS0, 1);
    self.logger.info('[DDPlayer] OCKS = 11 (128fs, up to 216kHz)');
  } else {
    gpioWrite(GPIO_OCKS1, 0);
    gpioWrite(GPIO_OCKS0, 0);
    self.logger.info('[DDPlayer] OCKS = 00 (256fs, up to 108kHz)');
  }
};

DDPlayerPlugin.prototype.getUIConfig = function() {
  const defer = libQ.defer();
  defer.resolve({
    page: { title: 'DDPlayer' },
    sections: [{
      title: 'GPIO Pin Assignment',
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
