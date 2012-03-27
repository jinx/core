package domain;

import java.util.Collection;
import java.util.ArrayList;

public class Child extends DomainObject implements Person
{
    /**
     * A string property.
     */
    private String name;

    /**
     * A boolean property.
     */
    private Boolean flag;

    /**
     * An integer property.
     */
    private Integer cardinal;

    /**
     * A decimal property.
     */
    private Double decimal;

    /**
     * This child's parent.
     * <p>
     * This property exercises a reference from a dependent to its owner.
     * </p>
     */
    private Parent parent;

    /**
     * This child's siblings.
     * <p>
     * This property exercises a 1:M self-reference.
     * </p>
     */
    private Collection<Child> friends;

    /**
     * This child's independent reference.
     * <p>
     * This property exercises a reference to an independent object.
     * </p>
     */
    private Independent indy;

    /**
     * This child's uni-directional dependent reference.
     * <p>
     * This property exercises a reference to a uni-directional dependent object.
     * </p>
     */
    private Dependent dependent;

    public Child()
    {
      friends = new ArrayList<Child>();
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
     * @return the flag
     */
    public Boolean getFlag()
    {
        return flag;
    }

    /**
     * @param flag the flag to set
     */
    public void setFlag(Boolean flag)
    {
        this.flag = flag;
    }

    /**
     * @return the decimal
     */
    public Double getDecimal()
    {
        return decimal;
    }

    /**
     * @param decimal the decimal to set
     */
    public void setDecimal(Double decimal)
    {
        this.decimal = decimal;
    }

    /**
     * @return the cardinal
     */
    public Integer getCardinal()
    {
        return cardinal;
    }

    /**
     * @param cardinal the cardinal to set
     */
    public void setCardinal(Integer cardinal)
    {
        this.cardinal = cardinal;
    }

    /**
     * @return the parent
     */
    public Parent getParent()
    {
        return parent;
    }

    /**
     * @param parent the parent to set
     */
    public void setParent(Parent parent)
    {
        this.parent = parent;
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
     * @return the friends
     */
    public Collection<Child> getFriends()
    {
        return friends;
    }

    /**
     * @param friends the friends to set
     */
    public void setFriends(Collection<Child> friends)
    {
        this.friends = friends;
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
