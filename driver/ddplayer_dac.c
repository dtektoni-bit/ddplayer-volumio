// SPDX-License-Identifier: GPL-2.0-only
/*
 * ASoC Driver for ddplayer DAC modified for AK
 *
 * Author:	Florian Meier <florian.meier@koalo.de>
 *		Copyright 2013
 *
 * modified by dsv0
 *
 * Ported to kernel 6.x ASoC component API
 */

#include <linux/module.h>
#include <linux/platform_device.h>

#include <sound/core.h>
#include <sound/pcm.h>
#include <sound/pcm_params.h>
#include <sound/soc.h>
#include <linux/gpio/consumer.h>

static struct gpio_desc *snd_rpi_ddplayer_clk48192gpio;
static struct gpio_desc *snd_rpi_ddplayer_clk4844gpio;
static struct gpio_desc *snd_rpi_ddplayer_clk96192gpio;
static struct gpio_desc *snd_rpi_ddplayer_mute;
static struct gpio_desc *snd_rpi_ddplayer_reset;

static bool has_external_clock;

#define CLK_44EN_RATE 22579200UL
#define CLK_48EN_RATE 24576000UL

static int samplerate = 44100;

static uint32_t snd_rpi_ddplayer_digi_enable_clock(int sample_rate)
{
	switch (sample_rate) {
	case 11025:
	case 22050:
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk4844gpio, 0);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk48192gpio, 0);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk96192gpio, 0);
		dev_dbg(NULL, "Using 44 Clock domain\n");
		return CLK_44EN_RATE;
	case 44100:
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk4844gpio, 0);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk48192gpio, 1);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk96192gpio, 0);
		dev_dbg(NULL, "Using 44 Clock domain\n");
		return CLK_44EN_RATE;
	case 48000:
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk4844gpio, 1);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk48192gpio, 1);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk96192gpio, 0);
		dev_dbg(NULL, "Using 48 Clock domain\n");
		return CLK_48EN_RATE;
	case 88200:
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk4844gpio, 0);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk48192gpio, 0);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk96192gpio, 1);
		dev_dbg(NULL, "Using 44 Clock domain\n");
		return CLK_44EN_RATE;
	case 96000:
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk4844gpio, 1);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk48192gpio, 0);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk96192gpio, 1);
		dev_dbg(NULL, "Using 48 Clock domain\n");
		return CLK_48EN_RATE;
	case 176400:
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk4844gpio, 0);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk48192gpio, 1);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk96192gpio, 1);
		dev_dbg(NULL, "Using 44 Clock domain\n");
		return CLK_44EN_RATE;
	case 192000:
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk4844gpio, 1);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk48192gpio, 1);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk96192gpio, 1);
		dev_dbg(NULL, "Using 48 Clock domain\n");
		return CLK_48EN_RATE;
	default:
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk4844gpio, 0);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk48192gpio, 1);
		gpiod_set_value_cansleep(snd_rpi_ddplayer_clk96192gpio, 0);
		dev_dbg(NULL, "Using 44 Clock domain (default)\n");
		return CLK_48EN_RATE;
	}
}

static int snd_rpi_ddplayer_dac_init(struct snd_soc_pcm_runtime *rtd)
{
	gpiod_set_value_cansleep(snd_rpi_ddplayer_reset, 1);
	return 0;
}

static int snd_rpi_ddplayer_dac_hw_params(struct snd_pcm_substream *substream,
					  struct snd_pcm_hw_params *params)
{
	struct snd_soc_pcm_runtime *rtd = snd_soc_substream_to_rtd(substream);
	struct snd_soc_dai *cpu_dai = snd_soc_rtd_to_cpu(rtd, 0);

	samplerate = params_rate(params);
	gpiod_set_value_cansleep(snd_rpi_ddplayer_mute, 1);
	snd_rpi_ddplayer_digi_enable_clock(samplerate);
	gpiod_set_value_cansleep(snd_rpi_ddplayer_mute, 0);

	return snd_soc_dai_set_bclk_ratio(cpu_dai, 64);
}

static const struct snd_soc_ops snd_rpi_ddplayer_dac_ops = {
	.hw_params = snd_rpi_ddplayer_dac_hw_params,
};

SND_SOC_DAILINK_DEFS(ddplayer,
	DAILINK_COMP_ARRAY(COMP_CPU("bcm2835-i2s.0")),
	DAILINK_COMP_ARRAY(COMP_CODEC("pcm5102a-codec", "pcm5102a-hifi")),
	DAILINK_COMP_ARRAY(COMP_PLATFORM("bcm2835-i2s.0")));

static struct snd_soc_dai_link snd_rpi_ddplayer_dac_dai[] = {
	{
		.name		= "ddplayer DAC",
		.stream_name	= "ddplayer DAC HiFi",
		.dai_fmt	= SND_SOC_DAIFMT_I2S |
				  SND_SOC_DAIFMT_NB_NF |
				  SND_SOC_DAIFMT_CBP_CFP,
		.ops		= &snd_rpi_ddplayer_dac_ops,
		.init		= snd_rpi_ddplayer_dac_init,
		SND_SOC_DAILINK_REG(ddplayer),
	},
};

static struct snd_soc_card snd_rpi_ddplayer_dac = {
	.name		= "snd_rpi_ddplayer_dac",
	.driver_name	= "ddplayerDac",
	.owner		= THIS_MODULE,
	.dai_link	= snd_rpi_ddplayer_dac_dai,
	.num_links	= ARRAY_SIZE(snd_rpi_ddplayer_dac_dai),
};

static int snd_rpi_ddplayer_dac_probe(struct platform_device *pdev)
{
	int ret;

	dev_info(&pdev->dev, "Probing ddplayer DAC\n");
	snd_rpi_ddplayer_dac.dev = &pdev->dev;

	if (pdev->dev.of_node) {
		struct device_node *i2s_node;
		struct snd_soc_dai_link *dai = &snd_rpi_ddplayer_dac_dai[0];

		i2s_node = of_parse_phandle(pdev->dev.of_node,
					    "i2s-controller", 0);
		if (i2s_node) {
			dai->cpus->dai_name = NULL;
			dai->cpus->of_node = i2s_node;
			dai->platforms->name = NULL;
			dai->platforms->of_node = i2s_node;
		}
	}

	has_external_clock = true;

	snd_rpi_ddplayer_clk4844gpio = devm_gpiod_get(&pdev->dev, "clock4844",
						       GPIOD_OUT_LOW);
	if (IS_ERR(snd_rpi_ddplayer_clk4844gpio)) {
		has_external_clock = false;
		dev_warn(&pdev->dev, "Can't get clock4844 from gpio\n");
	}

	snd_rpi_ddplayer_clk48192gpio = devm_gpiod_get(&pdev->dev, "clock48192",
							GPIOD_OUT_LOW);
	if (IS_ERR(snd_rpi_ddplayer_clk48192gpio)) {
		has_external_clock = false;
		dev_warn(&pdev->dev, "Can't get clock48192 from gpio\n");
	}

	snd_rpi_ddplayer_clk96192gpio = devm_gpiod_get(&pdev->dev, "clock96192",
							GPIOD_OUT_LOW);
	if (IS_ERR(snd_rpi_ddplayer_clk96192gpio)) {
		has_external_clock = false;
		dev_warn(&pdev->dev, "Can't get clock96192 from gpio\n");
	}

	snd_rpi_ddplayer_mute = devm_gpiod_get(&pdev->dev, "mute",
					       GPIOD_OUT_LOW);
	if (IS_ERR(snd_rpi_ddplayer_mute))
		dev_warn(&pdev->dev, "Can't get mute from gpio\n");

	snd_rpi_ddplayer_reset = devm_gpiod_get(&pdev->dev, "reset",
						GPIOD_OUT_LOW);
	if (IS_ERR(snd_rpi_ddplayer_reset))
		dev_warn(&pdev->dev, "Can't get reset from gpio\n");

	if (!has_external_clock)
		dev_info(&pdev->dev, "Clock is fixed\n");

	ret = devm_snd_soc_register_card(&pdev->dev, &snd_rpi_ddplayer_dac);
	if (ret && ret != -EPROBE_DEFER)
		dev_err(&pdev->dev, "snd_soc_register_card() failed: %d\n",
			ret);

	return ret;
}

static const struct of_device_id snd_rpi_ddplayer_dac_of_match[] = {
	{ .compatible = "ddplayer,ddplayer-dac", },
	{ },
};
MODULE_DEVICE_TABLE(of, snd_rpi_ddplayer_dac_of_match);

static struct platform_driver snd_rpi_ddplayer_dac_driver = {
	.driver = {
		.name		= "snd-ddplayer-dac",
		.of_match_table	= snd_rpi_ddplayer_dac_of_match,
	},
	.probe = snd_rpi_ddplayer_dac_probe,
};

module_platform_driver(snd_rpi_ddplayer_dac_driver);

MODULE_AUTHOR("Dima Sivov <dsivov@gmail.com>");
MODULE_DESCRIPTION("ASoC Driver for ddplayer DAC");
MODULE_LICENSE("GPL v2");
