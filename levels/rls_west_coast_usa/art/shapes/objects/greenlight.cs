
function greenlightDae::onLoad(%this)
{
   %this.addSequence("ambient", "tree_start", "0", "100", "1", "0");
   %this.setSequenceCyclic("tree_start", "0");
   %this.addSequence("ambient", "tree_end", "0", "10", "1", "0");
   %this.setSequenceCyclic("tree_end", "0");
   %this.setSequenceCyclic("ambient", "0");
}

singleton TSShapeConstructor(greenlightDae)
{
   baseShape = "./greenlight.dae";
};
