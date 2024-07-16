
singleton TSShapeConstructor(Pine_radiata_weatheredDae)
{
   baseShape = "./pine_radiata_weathered.dae";
};

function Pine_radiata_weatheredDae::onLoad(%this)
{
   %this.addImposter("25", "4", "0", "0", "256", "1", "0");
}
