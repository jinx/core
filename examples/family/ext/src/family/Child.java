package family;

import java.util.Collection;
import java.util.ArrayList;

public class Child extends Person
{
    private Collection<Parent> parents;

    public Child()
    {
        parents = new ArrayList<Parent>();
    }

    public Collection<Parent> getParents()
    {
        return parents;
    }

    public void setParents(Collection<Parent> parents)
    {
        this.parents = parents;
    }
}
