
singleton TSShapeConstructor(Cypress_treeDae)
{
   baseShape = "./cypress_tree.dae";
};

function Cypress_treeDae::onLoad(%this)
{
   %this.addImposter("25", "4", "0", "0", "256", "1", "0");
}
