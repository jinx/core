package domain;

import java.util.Collection;
import java.util.ArrayList;

public class Parent extends DomainObject implements Person
{
    /**
     * A string property.
     */
    private String name;

    /**
     * The parent's spouse.
     * <p>
     * This property exercises a 1:1 self-reference.
     * </p>
     */
    private Parent spouse;

    /**
     * This parent's children.
     * <p>
     * This property exercises a reference from an owner to dependents.
     * </p>
     */
    private Collection<Child> children;

    /**
     * This parent's independent reference.
     * <p>
     * This property exercises a reference to an independent object.
     * </p>
     */
    private Independent indy;

    /**
     * This parent's uni-directional dependent reference.
     * <p>
     * This property exercises a reference to a uni-directional dependent object.
     * </p>
     */
    private Dependent dependent;

    public Parent()
    {
        children = new ArrayList<Child>();
    }

    /**
     * @return the name
     */
    public String getName()
    {
        return name;
    }

    /**
     * @param name the name to set
     */
    public void setName(String name)
    {
        this.name = name;
    }

    /**
     * @return the spouse
     */
    public Parent getSpouse()
    {
        return spouse;
    }

    /**
     * @param spouse the spouse to set
     */
    public void setSpouse(Parent spouse)
    {
        this.spouse = spouse;
    }

    /**
     * @return the children
     */
    public Collection<Child> getChildren()
    {
        return children;
    }

    /**
     * @param children the children to set
     */
    public void setChildren(Collection<Child> children)
    {
        this.children = children;
    }

    /**
     * @return the child independent reference
     */
    public Independent getIndy()
    {
        return indy;
    }

    /**
     * @param indy the child independent reference to set
     */
    public void setIndy(Independent indy)
    {
        this.indy = indy;
    }
    
    /**
     * @return the dependent
     */
    public Dependent getDependent()
    {
        return dependent;
    }

    /**
     * @param dependent the dependent to set
     */
    public void setDependent(Dependent dependent)
    {
        this.dependent = dependent;
    }
}
