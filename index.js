'use strict';

const libQ = require('kew');

module.exports = DDPlayerPlugin;

function DDPlayerPlugin(context) {
  this.context = context;
  this.commandRouter = context.coreCommand;
  this.logger = context.logger;
}

DDPlayerPlugin.prototype.onVolumioStart = function() {
  const defer = libQ.defer();
  defer.resolve();
  return defer.promise;
};

DDPlayerPlugin.prototype.onStart = function() {
  const defer = libQ.defer();
  this.logger.info('[DDPlayer] Plugin started');
  defer.resolve();
  return defer.promise;
};

DDPlayerPlugin.prototype.onStop = function() {
  const defer = libQ.defer();
  this.logger.info('[DDPlayer] Plugin stopped');
  defer.resolve();
  return defer.promise;
};

DDPlayerPlugin.prototype.getUIConfig = function() {
  const defer = libQ.defer();
  defer.resolve({
    page: { title: 'DDPlayer DAC' },
    sections: [{
      title: 'DDPlayer DAC',
      content: [
        { element: 'label', label: 'DDPlayer I2S Slave DAC with external clock generator' },
        { element: 'label', label: 'GPIO 5  - clock4844 (44.1k/48k select)' },
        { element: 'label', label: 'GPIO 6  - clock48192 (48k/192k select)' },
        { element: 'label', label: 'GPIO 13 - clock96192 (96k/192k select)' },
        { element: 'label', label: 'GPIO 16 - mute' },
        { element: 'label', label: 'GPIO 26 - reset' },
      ]
    }]
  });
  return defer.promise;
};

DDPlayerPlugin.prototype.getConfigurationFiles = function() {
  return ['config.json'];
};
